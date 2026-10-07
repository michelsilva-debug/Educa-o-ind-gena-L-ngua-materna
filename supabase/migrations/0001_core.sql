-- Núcleo inicial de governança comunitária.
-- Não contém vocabulário, alfabeto ou regras linguísticas específicas.

create extension if not exists pgcrypto;


create type public.content_status as enum ('draft','under_review','community_validated','published','rejected','archived');
create type public.content_access as enum ('school','community','restricted');
create type public.validation_decision as enum ('approved','rejected','needs_revision');

create table public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.clans (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (community_id, name)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  community_id uuid references public.communities(id),
  clan_id uuid references public.clans(id),
  created_at timestamptz not null default now()
);

create table public.community_roles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null,
  created_at timestamptz not null default now()
);

create table public.contents (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null,
  description text,
  category text not null,
  status public.content_status not null default 'draft',
  access_level public.content_access not null default 'school',
  source_description text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.content_versions (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.contents(id) on delete cascade,
  version_number integer not null,
  body jsonb not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(content_id, version_number)
);

create table public.content_validations (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.contents(id) on delete cascade,
  clan_id uuid references public.clans(id),
  validator_profile_id uuid references public.profiles(id),
  decision public.validation_decision not null,
  comment text,
  created_at timestamptz not null default now()
);

create table public.curriculum_objectives (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null,
  description text,
  school_year text,
  subject text,
  created_at timestamptz not null default now()
);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null,
  instructions jsonb not null default '{}'::jsonb,
  objective_id uuid references public.curriculum_objectives(id),
  status public.content_status not null default 'draft',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.activity_contents (
  activity_id uuid not null references public.activities(id) on delete cascade,
  content_id uuid not null references public.contents(id) on delete restrict,
  primary key (activity_id, content_id)
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- RLS: habilitada desde o início; políticas detalhadas serão construídas junto
-- com o modelo real de papéis definido pela comunidade.
alter table public.communities enable row level security;
alter table public.clans enable row level security;
alter table public.profiles enable row level security;
alter table public.community_roles enable row level security;
alter table public.contents enable row level security;
alter table public.content_versions enable row level security;
alter table public.content_validations enable row level security;
alter table public.curriculum_objectives enable row level security;
alter table public.activities enable row level security;
alter table public.activity_contents enable row level security;
alter table public.audit_events enable row level security;

