# Educação Indígena — Língua Materna

## Plataforma de Educação Intercultural Enawenê-Nawê

Núcleo inicial de uma plataforma **offline-first** para apoio à Educação Escolar Indígena, construída sob um princípio fundamental:

> **A comunidade define. A tecnologia organiza.**

O software não define conteúdo linguístico, cultural ou tradicional. A comunidade, por meio de seus mecanismos próprios de governança e dos 9 clãs, deverá definir, revisar, autorizar e validar esses conteúdos.

Pessoas não indígenas podem atuar como facilitadores técnicos, pesquisadores, desenvolvedores e organizadores, conforme as regras estabelecidas pela comunidade. A IA não possui autoridade cultural e não pode inventar ou validar conhecimento comunitário.

## O que esta versão contém

- núcleo de governança comunitária;
- papéis e permissões tipados;
- representantes vinculados a clãs;
- política configurável de validação;
- validação por clã;
- proteção contra validador não autorizado;
- proteção contra publicação sem validação suficiente;
- auditoria das decisões;
- níveis de acesso para conteúdos;
- painel inicial de governança;
- base inicial para currículo e atividades;
- arquitetura preparada para funcionamento offline-first.

## Regra de ouro

Nenhuma regra de alfabeto, família silábica, vocabulário, tradição, narrativa, conhecimento tradicional ou forma de ensino é assumida pelo software como verdade antes de ser definida e validada pela comunidade.

Os nomes e identificadores dos 9 clãs usados no protótipo são placeholders técnicos. Eles não representam nomes oficiais nem características dos clãs.

## Arquitetura

```text
COMUNIDADE / 9 CLÃS
        ↓
GOVERNANÇA
        ↓
CONHECIMENTO COMUNITÁRIO
        ↓
REVISÃO / VALIDAÇÃO
        ↓
CONTEÚDO AUTORIZADO
        ↓
PROFESSOR INDÍGENA
        ↓
ATIVIDADE / AVALIAÇÃO
        ↓
ALUNO
```

A IA será subordinada a esse fluxo:

```text
CONTEÚDO AUTORIZADO
        ↓
      IA
        ↓
SUGESTÃO / ORGANIZAÇÃO
        ↓
REVISÃO HUMANA
        ↓
APLICAÇÃO
```

## Estrutura

- `apps/web/` — painel/protótipo web de governança.
- `supabase/migrations/` — modelo inicial de dados e regras de governança.
- `docs/` — arquitetura, decisões e princípios de governança.

## Próximas fases

1. Confirmar papéis e fluxo de governança com a comunidade.
2. Implementar autenticação e gestão de membros.
3. Conectar o painel ao Supabase.
4. Criar cadastro de conhecimento comunitário.
5. Definir, com a comunidade, o módulo linguístico.
6. Currículo e atividades.
7. PWA/offline-first e sincronização.
8. IA restrita a conteúdo autorizado.
9. Piloto e avaliação comunitária/pedagógica.
