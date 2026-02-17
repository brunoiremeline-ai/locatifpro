#!/usr/bin/env bash
set -euo pipefail

# Docker Compose: compat "docker compose" / "docker-compose"
if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose)
else
  echo "ERROR: Docker Compose introuvable (docker compose / docker-compose)."
  exit 1
fi

REF="${1:-}"
if [[ -z "${REF}" ]]; then
  echo "Usage: $0 <REFERENCE_PAIEMENT>"
  exit 1
fi

cat scripts/check_paiement_ref.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro -v "ref=${REF}"
