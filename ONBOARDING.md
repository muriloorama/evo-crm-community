# 👋 Onboarding (5 minutos)

> Você é um agente IA (Claude Code, Cursor, Copilot, ChatGPT…) ou dev humano que acabou de ser jogado neste projeto pela primeira vez. Esta página te deixa produtivo em **5 minutos**. Se quiser mais profundidade depois, leia [README.md](./README.md) (overview) e [AGENTS.md](./AGENTS.md) (manual operacional completo).

---

## 1. O que é isso

Plataforma de **atendimento ao cliente com agentes IA**, multi-workspace (cada cliente tem seu próprio "workspace" isolado na mesma instância), com chat WhatsApp, pipelines kanban, follow-up automático e integração com Meta Ads.

É um **fork divergente** de [EvolutionAPI/evo-crm-community](https://github.com/EvolutionAPI/evo-crm-community). Reescrevemos pra suportar N workspaces (originalmente era single-tenant) + adicionamos várias features. **Não fazemos `git pull` do upstream** — divergiu demais. Veja seção "Estratégia em relação ao upstream" no README.

---

## 2. Onde mora o código

Repo único (com submodules):

```
https://github.com/muriloorama/evo-crm-community  ← parent monorepo (público)
  ├── evo-auth-service-community/    Auth + JWT + super-admin (Ruby/Rails)
  ├── evo-ai-crm-community/          CRM principal — conversas, contatos (Ruby/Rails)
  ├── evo-ai-frontend-community/     UI web (React/TS)
  ├── evo-ai-core-service-community/ Storage de prompts dos agentes IA (Go)
  ├── evo-ai-processor-community/    Execução dos agentes IA (Python ADK)
  ├── evo-bot-runtime/               Dispatch + debounce (Go)
  └── evolution-api/                 Provider WhatsApp Baileys (opcional)
```

Os 4 primeiros são forks pessoais (`muriloorama/`). Os 3 últimos vêm direto do upstream EvolutionAPI.

---

## 3. Subir do zero

```bash
git clone --recurse-submodules https://github.com/muriloorama/evo-crm-community.git
cd evo-crm-community
cp .env.example .env                                      # configurar credenciais
docker compose up -d --build                              # ~10-20min na primeira vez
docker compose exec evo-auth bin/rails runner /rails/lib/tasks/bootstrap_admin.rb
```

Acesse `http://localhost:5173` (ou domínio configurado). Logue com o user/senha do bootstrap → cai no workspace #1.

---

## 4. Conceitos críticos pra não quebrar nada

| Conceito | Resumo | Detalhe em |
|---|---|---|
| **Multi-workspace** | Toda tabela tem `account_id`. `Accountable` concern faz default_scope automático. | AGENTS.md > "Conceitos críticos" |
| **`Current.account_id`** | Thread-local seteado por `EvoAuthConcern` em cada request. **Nil em jobs Sidekiq** — wrappar com `Accountable.with_account(...)`. | AGENTS.md > "Gotchas" |
| **URLs Chatwoot-style** | `/app/accounts/:n/conversations/:displayId`. Use o hook `useAccountPath()` no front. | AGENTS.md |
| **Prompt dos agentes IA** | Mora no DB `evo_community.evo_core_agents.instruction`, **não no repo**. Update live, sem restart. | AGENTS.md > "Como atualizar o prompt" |
| **Ignorar upstream** | Não puxe `EvolutionAPI/*` nos 4 forks. Cherry-pick fix crítico só se necessário. | README.md > "Estratégia upstream" |

---

## 5. Comandos do dia a dia

```bash
# Status dos containers
docker compose ps

# Logs ao vivo
docker compose logs -f evo-crm

# Console Rails
docker compose exec evo-crm bin/rails console
docker compose exec evo-auth bin/rails console

# Rodar migration nova
docker compose exec evo-crm bin/rails db:migrate

# Rebuildar frontend após mexer em código
docker compose build evo-frontend && docker compose up -d evo-frontend

# Atualizar prompt do agente IA (substitui <agent_uuid>)
docker exec evo-crm-community-postgres-1 psql -U postgres -d evo_community -c \
  "UPDATE evo_core_agents SET instruction = '<novo prompt>' WHERE id = '<uuid>'"
```

---

## 6. Antes de pedir ajuda

1. Leu o `README.md`?
2. Leu o `AGENTS.md`?
3. Conferiu se sua dúvida cai em "Gotchas" do AGENTS.md?
4. Olhou o `git log --oneline -20` pra entender o contexto recente?

Se sim e ainda travou — chama o dono.

---

**Próximo passo recomendado:** abre o [AGENTS.md](./AGENTS.md), lê tudo. Vai te dar o mental model completo em mais 10 minutos. Depois disso você está apto a contribuir com qualquer parte do projeto.
