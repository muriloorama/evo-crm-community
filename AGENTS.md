# AGENTS.md — contexto para agentes IA (Claude Code, Cursor, Copilot)

> Este arquivo é a **bíblia operacional** do projeto. Leia antes de qualquer mudança não-trivial. Mantém você produtivo em minutos em vez de horas.

---

## O que é este projeto

Fork **multi-workspace** de [EvolutionAPI/evo-crm-community](https://github.com/EvolutionAPI/evo-crm-community) — uma plataforma open-source de atendimento ao cliente com agentes IA. Originalmente single-tenant, foi reescrito pra suportar **N workspaces independentes** na mesma instância (row-level tenancy estilo Chatwoot/Slack), com painel super-admin, URLs `/app/accounts/:n/conversations/:displayId`, follow-ups com IA, integração Meta Ads, e outros.

**3 forks divergentes** (não puxam upstream): `evo-auth-service-community`, `evo-ai-crm-community`, `evo-ai-frontend-community`.
**4 submodules upstream** (puxam normal do EvolutionAPI): processor (Python), core-service (Go), bot-runtime (Go), evolution-api (Node).

---

## Arquitetura em 30 segundos

```
                    Browser
                       │
                       ▼
            evo-ai-frontend (5173)  ◄── React SPA, Vite build
                  │            │
                  │            └─► evo-auth-service (3001)  ◄── Rails 7.1, Doorkeeper JWT
                  │                       │
                  ▼                       │
            evo-ai-crm (3000)  ◄──────────┘ (validate_token via HTTP)
                  │
                  ├─► evo-bot-runtime (8080)  ◄── Go, dispatch + debounce
                  │         │
                  │         └─► evo-ai-processor (8000)  ◄── Python, ADK, MCP, tools
                  │
                  └─► evo-ai-core-service (5555)  ◄── Go, agent CRUD + storage de prompts
```

- **Auth** emite JWT (Doorkeeper). CRM valida via HTTP toda request (cache Rails 20s).
- **CRM** é o coração: conversas, contatos, inboxes, pipelines, follow-ups, tracking, broadcasts.
- **Processor** roda os agentes IA (ADK + tools incluindo CRM tools).
- **Core-service** guarda os prompts dos agentes (`evo_core_agents.instruction`).
- **Bot-runtime** orquestra: recebe mensagem → debounce → POST processor → POST CRM postback.

Detalhes por serviço, ver `README.md` de cada submodule.

---

## Conceitos críticos do multi-workspace (LEIA)

### Account model
- **Tabela `accounts` no Auth service** (UUID id + `number` sequencial Chatwoot-style 1, 2, 3...).
- `number` é gerado por sequence PostgreSQL `accounts_number_seq` (nunca regride mesmo após delete).
- CRM **não tem** tabela `accounts` própria — só usa `account_id :uuid` como FK lógico (não há FK real porque é cross-DB).

### Current.account_id
- `lib/current.rb` no CRM: thread-local `account_id`, `account_number`, `super_admin`, `accounts`.
- Populado pelo `EvoAuthConcern#set_current_user_from_auth_data` em cada request.
- **Toda query no CRM** deve respeitar `Current.account_id` — feito automaticamente via `Accountable` concern.

### Accountable concern
- `app/models/concerns/accountable.rb` no CRM: `default_scope { where(account_id: Current.account_id) }`.
- Aplicado em **~50 models** via `config/initializers/accountable_models.rb`.
- Auto-fill `account_id` no `before_validation` (create).
- **Bypass**: `Accountable.with_account(uuid) { ... }` (uso em jobs/services fora do request cycle), ou `Accountable.as_super_admin { ... }` (cross-account explícito).
- **Atenção em jobs Sidekiq**: `Current.account_id` é nil dentro do worker. Sempre wrappar:
  ```ruby
  Accountable.with_account(conversation.account_id) do
    # criação/leitura de modelos com account_id
  end
  ```
  Listeners/jobs já wrappados: `EventDispatcherJob`, `AgentBots::ResponseProcessor`, `MessageCreator`, `Conversations::ActivityMessageJob`, e os 8 webhook jobs (SMS, Telegram, Line, Twilio, Facebook, Instagram, WhatsApp, Evolution, UAZAPI).

### URLs estilo Chatwoot
- Frontend: rotas `/app/accounts/:accountNumber/conversations/:displayId`.
- Hook `useAccountPath()` em `src/hooks/useAccountPath.ts` constrói paths.
- `<AccountGuard />` em `src/routes/AccountGuard.tsx` valida URL accountNumber vs JWT — chama `switchAccount({ number })` se diferentes.
- `<LegacyAccountRedirect />` em `src/routes/index.tsx` redireciona paths antigos (`/conversations`, `/dashboard`...) pro novo formato.
- Conversation `display_id` é **per-account, sequencial, não regride** — gerado por `conversation_display_id_counters` table com UPSERT atômico em `Conversation#ensure_display_id`.

### JWT shape
```json
{
  "sub": "<user uuid>",
  "email": "...",
  "super_admin": true,
  "active_account_id": "<uuid>",
  "active_account_number": 1,
  "accounts": [
    { "id": "...", "number": 1, "name": "Workspace X", "slug": "...", "status": "active",
      "role": { "id": "...", "key": "account_owner", "name": "Admin" } }
  ]
}
```

### Super-admin
- Role global (sem `account_id`). Vê tudo, opera sobre qualquer workspace via `WorkspaceSwitcher`.
- `Current.super_admin?` no CRM, `useAuthStore(s => s.superAdmin)` no frontend.
- **NÃO** pula `default_scope` automaticamente — precisa `Accountable.as_super_admin { ... }` explícito (decisão consciente: evita vazamento acidental cross-workspace).
- Endpoints super-admin no Auth: `/api/v1/admin/{accounts,memberships,users}`.

---

## Onde mora cada coisa

| Coisa | Lugar |
|---|---|
| Prompt do agente IA | `evo_core_agents.instruction` no DB `evo_community` (não no repo!) |
| Config do bot por inbox | `agent_bots.bot_config` JSONB |
| Tags de anexo (PDF/imagem que o bot manda) | `agent_bots.bot_config.attachment_tags` — processadas por `AgentBots::TagProcessor` |
| Follow-up rules | tabela `follow_up_rules` (UI: `/follow-ups`) |
| Tracking de campanha (CTWA + UTM) | tabela `tracking_sources`, capturada por `TrackingSources::CaptureService` no `incoming_message_uazapi_service.rb` |
| Investimento Meta Ads | tabelas `meta_ad_accounts` + `campaign_investments`; sync diário via `MetaAds::SyncJob` (cron 5am) |
| Pipeline kanban | tabelas `pipelines`, `pipeline_stages`, `pipeline_items` |
| Sessão ADK do agente | tabela `sessions` (formato `session_id = {display_id}_{agent_id}`) |
| Tracking memory pra esta conversa | `Current.account_id`, `Current.user`, `Current.bearer_token` |

---

## Convenções

### Estilo de commit (do upstream Evolution + nosso)
- `feat(scope): ...` — feature nova
- `fix(scope): ...` — bug fix
- `chore(scope): ...` — refactor, deps, build
- `docs(scope): ...` — docs
- Mensagem em **inglês** ou **português**, mas seja consistente dentro de cada commit.
- Footer `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` quando o trabalho foi feito com agente IA.

### Migrations
- Auth service: timestamps prefixados com `9` (`90260424...`) — convenção do upstream pra ordenar depois de Devise/Doorkeeper migrations.
- CRM: timestamps padrão `YYYYMMDDHHMMSS`.
- **Sempre** adicionar `account_id` em tabela nova (NOT NULL) e incluir `Accountable` no model — senão quebra multi-tenancy.
- Backfill de tabelas existentes: usa `WITH ... ROW_NUMBER() ... UPDATE FROM` patterns (ver `90260424120000_add_number_to_accounts.rb` como exemplo).

### Frontend
- TS estrito (`tsc -b` rodado no build).
- Usar `useAccountPath()` para gerar URLs internas — nunca hardcoded `/conversations/...`.
- Estado global: zustand (`src/store/*`).
- API calls: services em `src/services/*`, NUNCA dentro do componente direto.
- i18n: 6 locales (en, es, fr, it, pt, pt-BR) — adicionar chave em todos.

### Backend Rails
- Permissões: cada request é validada via Auth service. `has_permission?` no CRM hoje retorna sempre true (single-tenant heritage); permissão real é via Auth role.
- Serializers em `app/serializers/`. Sempre incluir `display_id` quando expuser Conversation.
- Sidekiq workers em `app/jobs/`. Wrappar com `Accountable.with_account(...)` se criar/ler modelos.
- Eventos: `Events::Base.send_event(:event_name, data:)`. Listeners em `app/listeners/` registrados no `AsyncDispatcher`.

---

## Gotchas conhecidos

1. **`Current.account_id` nil em job Sidekiq** → `PG::NotNullViolation: account_id` em quase todo create. Sempre wrappar com `Accountable.with_account(...)`.
2. **`acts_as_taggable_on::Tag` não inclui Accountable** automaticamente — initializer `acts_as_taggable_accountable.rb` injeta via `to_prepare`. Se virar Tag mexer em outro lugar, esse hack pode quebrar.
3. **Sidekiq-cron exige `active_job: true`** em cada entry de `config/schedule.yml`. Sem isso o job quebra com `NoMethodError: undefined method 'jid='`.
4. **Reauthorization stuck**: se um channel ficar com `reauthorization_required: true`, webhooks são descartados como inactive mesmo após reconnect via QR. Fix: `channel.reauthorized!` via runner.
5. **Country code Hash bug** em UAZAPI: `phoneNumber.country_code` às vezes vem como Hash. Tratado em `app/builders/contact_inbox_with_contact_builder.rb`.
6. **Sessão ADK reset**: se o agente IA deve "esquecer" contexto, marca a tag `[[#reset]]` no prompt — limpa sessão via `delete_session_job.rb`.
7. **Super-admin pode acidentalmente operar no workspace errado** se a UI não validar URL vs JWT. `AccountGuard` cobre isso, mas se você criar nova rota fora do `/app/accounts/:n/...` tree, pode vazar.

---

## Como atualizar o prompt de um agente

```bash
docker cp /tmp/prompt.txt evo-crm-community-postgres-1:/tmp/prompt.txt
docker exec evo-crm-community-postgres-1 bash -c "psql -U postgres -d evo_community <<'SQL'
\set newprompt \`cat /tmp/prompt.txt\`
UPDATE evo_core_agents SET instruction = :'newprompt', updated_at = NOW() WHERE id = '<agent_uuid>';
SQL"
```
**Live update — sem restart.** O `evo-bot-runtime` lê do `evo-ai-core-service` a cada request.

---

## Estratégia de relacionamento com upstream EvolutionAPI

**Política**: ignorar. Os 3 forks divergiram demais — qualquer `git pull` daria conflito em quase todo arquivo.

Para acompanhar bug fixes críticos do upstream:
```bash
cd evo-ai-crm-community
git fetch origin main         # 'origin' aqui é EvolutionAPI por convenção
git log origin/main --oneline # vê o que tem novo
git cherry-pick <sha>         # traz só o que importa, resolve conflito, testa
```

Os 4 submodules **não modificados** (`processor`, `core-service`, `bot-runtime`, `evolution-api`) podem ser atualizados normalmente:
```bash
git submodule update --remote --merge evo-ai-processor-community
```

---

## Checklist antes de fazer PR / push

- [ ] Migrations rodam limpas (`docker compose exec evo-crm bin/rails db:migrate`)
- [ ] TypeScript compila (`docker run --rm -v $(pwd):/app -w /app node:20-alpine npx tsc -b`)
- [ ] Frontend rebuilda sem erro (`docker compose build evo-frontend`)
- [ ] Containers ficam healthy (`docker compose ps`)
- [ ] Smoke test: login → ver workspace #N na URL → trocar workspace → ver dados isolados
- [ ] Se mexeu em prompt do agente: testou conversa real no WhatsApp
- [ ] Adicionou ou atualizou memory note no `.claude/projects/-root-evo-crm-community/memory/` (se rodando com Claude Code)

---

## Quem mantém

Fork pessoal de **muriloorama** (Murilo Amaro). Originado em Abril/2026 a partir de [EvolutionAPI/evo-crm-community](https://github.com/EvolutionAPI/evo-crm-community).

Pra acompanhar issues/discussões da plataforma upstream: [evolutionfoundation.com.br/community](https://evolutionfoundation.com.br/community).
