# EVO CRM (multi-workspace fork)

> **Fork divergente de [EvolutionAPI/evo-crm-community](https://github.com/EvolutionAPI/evo-crm-community).**
> Esta variante adiciona row-level multi-tenancy (workspaces independentes na mesma instância), painel super-admin, URLs estilo Chatwoot (`/app/accounts/:n/conversations/:displayId`), follow-ups com IA, integração Meta Ads para tracking de campanhas, broadcasts, scheduled messages, provider WhatsApp UAZAPI, entre outras features. **Não puxa updates do upstream** — divergência grande demais. Veja [docs/upstream-strategy.md](#estratégia-em-relação-ao-upstream) abaixo.

Tudo que esse monorepo precisa pra rodar do zero:

```bash
git clone --recurse-submodules https://github.com/muriloorama/evo-crm-community.git
cd evo-crm-community
cp .env.example .env   # ajuste credenciais
docker compose up -d --build
```

A primeira subida demora alguns minutos (build dos serviços + bundle install). Quando todos ficarem `healthy`, acesse `http://localhost:5173` e siga o setup wizard pra criar o super-admin inicial.

---

## Arquitetura

7 serviços orquestrados via `docker compose`. Os 3 primeiros sofreram modificações pesadas (apontam para forks em `muriloorama/`); os outros são pulled do upstream `EvolutionAPI/`.

| Serviço | Função | Stack | Porta | Origem |
|---|---|---|---|---|
| `evo-auth-service-community` | Auth, RBAC, OAuth2, JWT, painel super-admin, Account model | Ruby 3.4 / Rails 7.1 | `3001` | **fork** |
| `evo-ai-crm-community` | Conversas, contatos, inboxes, pipelines, follow-ups, tracking, broadcasts | Ruby 3.4 / Rails 7.1 | `3000` | **fork** |
| `evo-ai-frontend-community` | UI web (multi-workspace, chat, dashboards, super-admin) | React + TS + Vite | `5173` | **fork** |
| `evo-ai-processor-community` | Execução de agentes IA (ADK + tools + MCP) | Python 3.10 / FastAPI | `8000` | upstream |
| `evo-ai-core-service-community` | CRUD de agentes, API keys, folders | Go / Gin | `5555` | upstream |
| `evo-bot-runtime` | Pipeline de bot, debouncing, dispatch | Go / Gin | `8080` | upstream |
| `evolution-api` | Provider WhatsApp Baileys (opcional, escondido na UI) | Node | — | upstream |

Infra adicional (no parent):
- `postgres:16` — DB compartilhado (databases: `evo_community`, `evo_auth_community`, `evo_processor_community`, `evolution_api`)
- `redis:7` — cache + sidekiq + ActionCable
- `caddy` (opcional, em `docker-compose.caddy.yml`) — reverse proxy + HTTPS automático

---

## Diferenças vs upstream EvolutionAPI

| Área | EvolutionAPI/* (upstream) | Este fork |
|---|---|---|
| Tenancy | Single-tenant (1 account fixo) | **Row-level multi-workspace** — `account_id` em todas tabelas, `Accountable` concern, `Current.account_id` thread-local |
| Account model | Singleton em `runtime_configs` JSON | Tabela `accounts` real, `Account.number` sequencial estilo Chatwoot, `slug`, `status` |
| Auth | Sem switch de account | `POST /auth/switch_account`, JWT carrega `active_account_id` + `active_account_number` + `accounts[]` |
| Painel admin | Não existe | `/super-admin/{accounts,users,memberships}` — CRUD completo de workspaces |
| URLs | `/conversations/:uuid` | `/app/accounts/:accountNumber/conversations/:displayId` (Chatwoot-style) |
| `display_id` | Global, reusa após delete | Per-account via `conversation_display_id_counters` — nunca regride |
| Follow-up automático | Não existe | `FollowUpRule` + `FollowUpExecution` + `FollowUps::SchedulerJob` |
| Tracking de campanha | Não existe | `tracking_sources` (CTWA + UTM) + `meta_ad_accounts` + sync diário Meta Ads |
| Broadcasts | Não existe | `broadcast_campaigns` + `broadcast_recipients` |
| Scheduled messages | Não existe | `scheduled_messages` |
| Providers WhatsApp na UI | Cloud + Baileys + Evolution | Cloud + UAZAPI (Baileys/Evolution escondidos via UI) |

---

## Setup detalhado

### 1. Pré-requisitos

- Docker 24+ e Docker Compose v2
- Git 2.40+ (para submodules)
- 4 GB RAM mínimo, 8 GB recomendado
- Em produção atrás de domínio: DNS apontado pro servidor + portas 80/443 abertas (se usar Caddy)

### 2. Clone

```bash
git clone --recurse-submodules https://github.com/muriloorama/evo-crm-community.git
cd evo-crm-community
```

Se já clonou sem submodules:

```bash
git submodule update --init --recursive
```

### 3. Configure variáveis

```bash
cp .env.example .env
```

Edite `.env` com:
- Credenciais Postgres (`POSTGRES_USER`, `POSTGRES_PASSWORD`)
- Credenciais Redis (`REDIS_PASSWORD`)
- URLs públicas dos serviços (`VITE_API_URL`, `VITE_AUTH_API_URL` etc.)
- Secret keys (gerar com `openssl rand -hex 32`): `DOORKEEPER_JWT_SECRET_KEY`, `SECRET_KEY_BASE`, `RAILS_MASTER_KEY`
- Credenciais SMTP (se for usar reset de senha por email)

### 4. Suba os serviços

```bash
docker compose up -d --build
```

A primeira subida builda imagens e roda `bundle install` (Auth + CRM) e `npm ci` (Frontend) — toma 10-20min. Após isso, restarts são rápidos.

### 5. Rode migrations + seeds

```bash
# Auth (cria roles/permissions base)
docker compose exec evo-auth bin/rails db:migrate db:seed

# CRM
docker compose exec evo-crm bin/rails db:migrate
```

### 6. Crie o super-admin inicial

```bash
docker compose exec evo-auth bin/rails runner /rails/lib/tasks/bootstrap_admin.rb
```

O script perguntará nome, email e senha. Cria o user com role `super_admin` global + `account_owner` no workspace default.

### 7. Acesse

- Frontend: `http://localhost:5173` (ou seu domínio)
- Login com email/senha do passo 6
- Você cai em `/app/accounts/1/conversations` (workspace #1 = "Evolution Community")
- Painel super-admin: ícone "Painel Super Admin" no dropdown do workspace

---

## Adicionar reverse proxy (Caddy + HTTPS automático)

Para produção atrás de domínio:

```bash
# Edite Caddyfile com seu domínio + email Let's Encrypt
nano Caddyfile

# Suba o Caddy junto com o stack
docker compose -f docker-compose.yml -f docker-compose.caddy.yml up -d
```

O Caddy provisiona certificados Let's Encrypt automaticamente. Reverse-proxy do `crm.seudominio` → `evo-frontend:80` por default; ajuste para incluir Auth/CRM se quiser expô-los.

---

## Adicionar provider WhatsApp Baileys (Evolution API)

Se quiser também usar o stack Evolution (Baileys nativo, alternativa ao UAZAPI):

```bash
docker compose -f docker-compose.yml -f docker-compose.evolution-api.yml up -d
```

O serviço `evolution-api` sobe + `evolution-api-db-init` cria o database `evolution_api` no postgres compartilhado.

> **Nota:** os providers Baileys e Evolution Go estão **escondidos da UI** mas o backend continua funcional. Se quiser reabilitar, edite `src/components/channels/forms/whatsapp/index.tsx` no frontend.

---

## Estrutura de pastas

```
evo-crm-community/                 # parent monorepo (este repo)
├── docker-compose.yml             # serviços principais
├── docker-compose.caddy.yml       # overlay opcional: reverse proxy + HTTPS
├── docker-compose.evolution-api.yml  # overlay opcional: Baileys provider
├── Caddyfile                      # config do Caddy
├── .env.example                   # template de variáveis
├── README.md                      # este arquivo
├── AGENTS.md                      # contexto pra agentes IA (Claude Code etc.)
├── TRADEMARKS.md                  # política de uso de marca da Evolution
│
├── evo-auth-service-community/    # submodule (fork)
├── evo-ai-crm-community/          # submodule (fork)
├── evo-ai-frontend-community/     # submodule (fork)
├── evo-ai-processor-community/    # submodule (upstream)
├── evo-ai-core-service-community/ # submodule (upstream)
├── evo-bot-runtime/               # submodule (upstream)
└── evolution-api/                 # submodule (upstream)
```

---

## Estratégia em relação ao upstream

Este fork divergiu **fortemente** dos repos `EvolutionAPI/*` (multi-workspace toca quase todo arquivo: `Accountable` em ~50 models, `account_id` em 47 tabelas, rotas refatoradas pra Chatwoot-style, etc).

**Política adotada:** *ignorar upstream*. Tratamos esses 3 forks como produto próprio.

- **Não fazemos `git pull origin main`** nos 3 submodules forkados — `merge` daria conflito em quase todo arquivo.
- Para acompanhar bug fixes críticos do upstream: `git fetch origin main` (origin = EvolutionAPI), inspeciona `git log origin/main --oneline`, e cherry-picka manualmente o que importa.
- Os 4 submodules **não** modificados (`evo-ai-processor-community`, `evo-ai-core-service-community`, `evo-bot-runtime`, `evolution-api`) podem ser atualizados normalmente do upstream EvolutionAPI.

Pra mudar push/pull URL local pra SSH (em vez de HTTPS):
```bash
git config submodule.evo-auth-service-community.url git@github.com:muriloorama/evo-auth-service-community.git
# repete para evo-ai-crm-community e evo-ai-frontend-community
git submodule sync
```

---

## Atualizar submodules

```bash
# Pull do main de cada fork (apenas os 3 modificados; os outros vêm do upstream)
git submodule update --remote --merge

# Após avançar, commita os novos pointers no parent
git add evo-auth-service-community evo-ai-crm-community evo-ai-frontend-community
git commit -m "chore(submodules): bump to latest main"
git push
```

---

## Comandos úteis

```bash
# Status dos containers
docker compose ps

# Logs ao vivo de um serviço
docker compose logs -f evo-crm

# Console Rails (Auth ou CRM)
docker compose exec evo-auth bin/rails console
docker compose exec evo-crm bin/rails console

# Rodar migration nova
docker compose exec evo-crm bin/rails db:migrate

# Rebuildar frontend após mexer em código
docker compose build evo-frontend && docker compose up -d evo-frontend

# Rodar bootstrap (cria primeiro super-admin)
docker compose exec evo-auth bin/rails runner /rails/lib/tasks/bootstrap_admin.rb
```

---

## Documentação adicional

- **[AGENTS.md](./AGENTS.md)** — contexto pra agentes IA (Claude Code, Cursor, Copilot) que forem trabalhar no projeto: arquitetura interna, convenções, gotchas e onde encontrar coisas.
- **README de cada submodule** — específicos de cada serviço.
- **Documentação upstream** — [docs.evolutionfoundation.com.br](https://docs.evolutionfoundation.com.br) (válida pra conceitos base, antes da multi-workspace).

---

## Licença

Apache 2.0 — herdada do upstream. Ver [LICENSE](./LICENSE) e [TRADEMARKS.md](./TRADEMARKS.md).
