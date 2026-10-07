# Arquitetura do sistema

## Domínios

### 1. Governança
- comunidades
- clãs
- usuários
- papéis
- permissões
- validações

### 2. Conhecimento comunitário
- conteúdos
- fontes/origem
- categoria
- nível de acesso
- status de validação
- histórico de versões
- responsáveis pela validação

### 3. Língua

O banco não assume previamente alfabeto, família silábica ou regras gramaticais. Esses elementos serão cadastrados somente depois da definição comunitária.

### 4. Educação
- etapas/anos
- componentes
- habilidades/objetivos curriculares
- atividades
- sequências didáticas
- avaliações

### 5. Tecnologia
- sincronização offline/online
- armazenamento local
- fila de sincronização
- auditoria
- IA com contexto autorizado

## Regra crítica

A IA nunca deve consultar diretamente um conjunto irrestrito de conhecimentos comunitários. A camada de autorização precisa filtrar o que pode ser usado na geração de uma atividade.
