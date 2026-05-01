#!/usr/bin/env bash
# Deploy controlado de produção.
#
# Uso:
#   ./scripts/deploy.sh                         # pull + restart de TUDO
#   ./scripts/deploy.sh evo-crm                 # rebuild só de evo-crm
#   ./scripts/deploy.sh evo-crm evo-frontend    # vários serviços
#
# Pré-requisitos:
#   - Estar no servidor de produção, dentro do diretório do repo
#   - Branch local = main, sem alterações não commitadas
#   - Submódulos com ponteiros já atualizados no commit que está em fork/main

set -euo pipefail

cd "$(dirname "$0")/.."

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

log()  { echo -e "${CYAN}==>${RESET} $*"; }
ok()   { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}!${RESET} $*"; }
fail() { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }

# 1. Sanity checks
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
  fail "Branch atual é '$CURRENT_BRANCH'. Produção só roda em main."
fi

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  warn "Existem alterações não commitadas no repo principal."
  git status --short
  read -r -p "Continuar mesmo assim? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || fail "Abortado."
fi

# 2. Snapshot do commit atual (pra rollback se precisar)
PREV_COMMIT=$(git rev-parse HEAD)
log "Commit atual: $PREV_COMMIT"

# 3. Pull do fork
log "git fetch fork..."
git fetch fork

NEW_COMMIT=$(git rev-parse fork/main)
if [ "$PREV_COMMIT" = "$NEW_COMMIT" ]; then
  ok "Já está no último commit ($NEW_COMMIT). Nada a puxar."
else
  log "Fast-forward para fork/main ($NEW_COMMIT)..."
  git merge --ff-only fork/main || fail "Não foi fast-forward. Resolve à mão."
fi

# 4. Atualiza submódulos pelo ponteiro do commit (NÃO --remote)
log "git submodule update..."
git submodule update --init --recursive

# 5. Build & up
if [ $# -eq 0 ]; then
  log "Rebuild de todos os serviços (pode demorar)..."
  docker compose build
  log "Subindo containers..."
  docker compose up -d
else
  log "Rebuild dos serviços: $*"
  docker compose build "$@"
  log "Reiniciando: $*"
  docker compose up -d "$@"
fi

# 6. Status
echo ""
docker compose ps
echo ""
ok "Deploy concluído. ($PREV_COMMIT → $NEW_COMMIT)"
echo ""
echo "Para reverter: git reset --hard $PREV_COMMIT && ./scripts/deploy.sh"
