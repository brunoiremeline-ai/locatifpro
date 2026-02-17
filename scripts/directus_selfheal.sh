#!/usr/bin/env bash
# Ne JAMAIS faire tomber le terminal : pas de -e, pas de pipefail fatal
set -u

log(){ echo "Directus self-heal: $*"; }

# Toujours sortir en 0 (même si docker/curl est KO) pour éviter “terminal fermé”
finish_ok(){ exit 0; }

# 0) Prérequis soft
command -v docker >/dev/null 2>&1 || { log "docker introuvable -> skip"; finish_ok; }
docker info >/dev/null 2>&1 || { log "docker daemon inaccessible -> skip"; finish_ok; }

# 1) DB accessible ?
./scripts/db_psql.sh -c "select 1" >/dev/null 2>&1 || { log "DB pas accessible via db_psql.sh -> skip"; finish_ok; }

# 2) Patch collisions (idempotent)
PATCHED="$(./scripts/db_psql.sh -qAt < scripts/patch_directus_relations_scalar_one_field.sql 2>/dev/null || echo 0)"
PATCHED="${PATCHED:-0}"
case "$PATCHED" in
  ''|*[!0-9]*) PATCHED=0 ;;
esac

if [ "$PATCHED" -gt 0 ]; then
  log "Patched ${PATCHED} relation(s). Restarting Directus..."
  docker compose restart directus >/dev/null 2>&1 || true

  # Attendre max 30s que Directus réponde (sans jamais échouer)
  for i in $(seq 1 30); do
    curl -fsS "http://localhost:8055/server/info" >/dev/null 2>&1 && { log "Directus back up."; finish_ok; }
    sleep 1
  done
  log "WARN: Directus pas encore répondant, mais on continue (pas bloquant)."
else
  log "OK: no collision detected."
fi

finish_ok
