#!/usr/bin/env bash
# Non-bloquant: ne jamais casser l'ouverture du Codespace.
set -u

log() { echo "Codespace start: $*"; }
finish_ok() { exit 0; }

if ! command -v docker >/dev/null 2>&1; then
  log "docker introuvable -> skip"
  finish_ok
fi

if ! docker info >/dev/null 2>&1; then
  log "docker daemon inaccessible -> skip"
  finish_ok
fi

if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose)
else
  log "docker compose introuvable -> skip"
  finish_ok
fi

log "Starting db + directus..."
"${DC[@]}" up -d db directus >/dev/null 2>&1 || {
  log "up ciblé échoué, fallback sur up global..."
  "${DC[@]}" up -d >/dev/null 2>&1 || finish_ok
}

for i in $(seq 1 45); do
  curl -fsS "http://localhost:8055/server/health" >/dev/null 2>&1 && break
  sleep 1
done

./scripts/directus_selfheal.sh >/dev/null 2>&1 || true
log "Directus startup routine done."
finish_ok
