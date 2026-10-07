-- Núcleo de governança comunitária v2.
-- Regra: somente pessoas autorizadas pela própria comunidade podem validar
-- conteúdo comunitário. Suporte técnico, pesquisadores e IA não recebem
-- autoridade de validação por padrão.

create type public.governance_role as enum (
  'community_governance',
  'clan_representative',
  'indigenous_teacher',
  'reviewer',
  'technical_support',
  'researcher',
  'student',
  'observer'
);

create type public.validation_mode as enum (
  'all_clans',
  'quorum',
  'designated_clans'
);

create table public.governance_policies (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null unique references public.communities(id) on delete cascade,
  validation_mode public.validation_mode not null default 'all_clans',
  minimum_clans integer not null default 9 check (minimum_clans > 0),
  publication_requires_community_validation boolean not null default true,
  allow_non_indigenous_authors boolean not null default true,
  allow_ai_assistance boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.governance_policy_clans (
  policy_id uuid not null references public.governance_policies(id) on delete cascade,
  clan_id uuid not null references public.clans(id) on delete cascade,
  primary key (policy_id, clan_id)
);

-- Substitui a string livre de papel por um papel tipado.
alter table public.community_roles
  add column if not exists governance_role public.governance_role;

-- Permissões explícitas. A comunidade poderá definir/restringir papéis no futuro
-- sem alterar o modelo de conteúdo.
create table public.role_permissions (
  role public.governance_role not null,
  permission text not null,
  primary key (role, permission)
);

insert into public.role_permissions(role, permission) values
  ('community_governance', 'manage_governance'),
  ('community_governance', 'manage_members'),
  ('community_governance', 'create_content'),
  ('community_governance', 'review_content'),
  ('community_governance', 'validate_content'),
  ('community_governance', 'publish_content'),
  ('clan_representative', 'create_content'),
  ('clan_representative', 'review_content'),
  ('clan_representative', 'validate_content'),
  ('indigenous_teacher', 'create_content'),
  ('indigenous_teacher', 'review_content'),
  ('reviewer', 'review_content'),
  ('technical_support', 'technical_access'),
  ('researcher', 'research_access'),
  ('student', 'student_access'),
  ('observer', 'read_only')
  on conflict do nothing;

-- Um perfil só pode ter papel em sua própria comunidade.
create or replace function public.profile_has_role(
  p_profile_id uuid,
  p_community_id uuid,
  p_role public.governance_role
) returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.community_roles cr
    join public.profiles p on p.id = cr.profile_id
    where cr.profile_id = p_profile_id
      and p.community_id = p_community_id
      and cr.governance_role = p_role
  );
$$;

create or replace function public.profile_has_permission(
  p_profile_id uuid,
  p_community_id uuid,
  p_permission text
) returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.community_roles cr
    join public.profiles p on p.id = cr.profile_id
    join public.role_permissions rp on rp.role = cr.governance_role
    where cr.profile_id = p_profile_id
      and p.community_id = p_community_id
      and rp.permission = p_permission
  );
$$;

create or replace function public.validator_is_authorized(
  p_profile_id uuid,
  p_community_id uuid,
  p_clan_id uuid
) returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.community_roles cr
    join public.profiles p on p.id = cr.profile_id
    join public.clans c on c.id = p.clan_id
    where cr.profile_id = p_profile_id
      and p.community_id = p_community_id
      and p.clan_id = p_clan_id
      and c.community_id = p_community_id
      and cr.governance_role in ('community_governance', 'clan_representative')
  );
$$;

-- Não permite registrar uma validação sem que o perfil tenha sido autorizado
-- pelo papel e pelo clã correspondentes.
create or replace function public.guard_content_validation()
returns trigger
language plpgsql
as $$
declare
  v_community_id uuid;
begin
  select community_id into v_community_id
  from public.contents
  where id = new.content_id;

  if v_community_id is null then
    raise exception 'Conteúdo não encontrado.';
  end if;

  if new.clan_id is null then
    raise exception 'Toda validação comunitária deve identificar o clã validador.';
  end if;

  if not public.validator_is_authorized(new.validator_profile_id, v_community_id, new.clan_id) then
    raise exception 'Perfil não autorizado a validar conteúdo em nome deste clã.';
  end if;

  return new;
end;
$$;

create trigger trg_guard_content_validation
before insert or update on public.content_validations
for each row execute function public.guard_content_validation();

-- Impede publicação de conteúdo comunitário quando a política exige validação
-- e o número/abrangência de validações ainda não foi atingido.
create or replace function public.guard_content_publication()
returns trigger
language plpgsql
as $$
declare
  v_policy public.governance_policies%rowtype;
  v_approved integer;
  v_required integer;
begin
  if new.status <> 'published' then
    return new;
  end if;

  select * into v_policy
  from public.governance_policies
  where community_id = new.community_id;

  if not found or not v_policy.publication_requires_community_validation then
    return new;
  end if;

  select count(distinct cv.clan_id)
    into v_approved
  from public.content_validations cv
  where cv.content_id = new.id
    and cv.decision = 'approved';

  if v_policy.validation_mode = 'all_clans' then
    select count(*) into v_required
    from public.clans c
    where c.community_id = new.community_id;
  elsif v_policy.validation_mode = 'designated_clans' then
    select count(*) into v_required
    from public.governance_policy_clans pc
    join public.clans c on c.id = pc.clan_id
    where pc.policy_id = v_policy.id
      and c.community_id = new.community_id;

    if exists (
      select 1
      from public.governance_policy_clans pc
      where pc.policy_id = v_policy.id
        and not exists (
          select 1
          from public.content_validations cv
          where cv.content_id = new.id
            and cv.clan_id = pc.clan_id
            and cv.decision = 'approved'
        )
    ) then
      raise exception 'Conteúdo ainda não foi aprovado por todos os clãs designados pela comunidade.';
    end if;
  else
    v_required := v_policy.minimum_clans;
  end if;

  if v_approved < greatest(v_required, 1) then
    raise exception 'Conteúdo não pode ser publicado: validação comunitária insuficiente (% de % clãs).', v_approved, greatest(v_required, 1);
  end if;

  return new;
end;
$$;

create trigger trg_guard_content_publication
before update of status on public.contents
for each row execute function public.guard_content_publication();

-- Auditoria de decisões de validação.
create or replace function public.audit_content_validation()
returns trigger
language plpgsql
as $$
declare
  v_community_id uuid;
begin
  select community_id into v_community_id from public.contents where id = new.content_id;

  insert into public.audit_events(
    actor_profile_id,
    action,
    entity_type,
    entity_id,
    metadata
  ) values (
    new.validator_profile_id,
    'content_validation_' || new.decision::text,
    'content',
    new.content_id,
    jsonb_build_object(
      'clan_id', new.clan_id,
      'community_id', v_community_id,
      'comment', new.comment
    )
  );

  return new;
end;
$$;

create trigger trg_audit_content_validation
after insert on public.content_validations
for each row execute function public.audit_content_validation();

-- RLS adicional.
alter table public.governance_policies enable row level security;
alter table public.governance_policy_clans enable row level security;
alter table public.role_permissions enable row level security;

-- O usuário autenticado pode consultar políticas da comunidade à qual pertence.
create policy "members_can_read_governance_policy"
on public.governance_policies
for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.community_id = governance_policies.community_id
  )
);

create policy "members_can_read_policy_clans"
on public.governance_policy_clans
for select to authenticated
using (
  exists (
    select 1
    from public.governance_policies gp
    join public.profiles p on p.community_id = gp.community_id
    where gp.id = governance_policy_clans.policy_id
      and p.id = auth.uid()
  )
);

create policy "authenticated_can_read_role_permissions"
on public.role_permissions
for select to authenticated
using (true);

-- A administração comunitária será a única camada autorizada a alterar a política.
create policy "community_governance_can_manage_policy"
on public.governance_policies
for all to authenticated
using (public.profile_has_permission(auth.uid(), community_id, 'manage_governance'))
with check (public.profile_has_permission(auth.uid(), community_id, 'manage_governance'));

create policy "community_governance_can_manage_policy_clans"
on public.governance_policy_clans
for all to authenticated
using (
  exists (
    select 1
    from public.governance_policies gp
    where gp.id = governance_policy_clans.policy_id
      and public.profile_has_permission(auth.uid(), gp.community_id, 'manage_governance')
  )
)
with check (
  exists (
    select 1
    from public.governance_policies gp
    join public.clans c on c.id = governance_policy_clans.clan_id
    where gp.id = governance_policy_clans.policy_id
      and c.community_id = gp.community_id
      and public.profile_has_permission(auth.uid(), gp.community_id, 'manage_governance')
  )
);

-- Proteção contra associação de perfil a clã de outra comunidade.
create or replace function public.guard_profile_clan()
returns trigger
language plpgsql
as $$
begin
  if new.clan_id is not null and not exists (
    select 1 from public.clans c
    where c.id = new.clan_id
      and c.community_id = new.community_id
  ) then
    raise exception 'O clã informado não pertence à comunidade do perfil.';
  end if;
  return new;
end;
$$;

create trigger trg_guard_profile_clan
before insert or update on public.profiles
for each row execute function public.guard_profile_clan();

comment on table public.governance_policies is
  'Políticas de governança definidas pela própria comunidade; não assumir regras culturais externamente.';
comment on table public.governance_policy_clans is
  'Clãs participantes de uma política específica de validação, definidos pela comunidade.';
comment on table public.content_validations is
  'Decisões de validação feitas por representantes autorizados da comunidade/clãs.';
