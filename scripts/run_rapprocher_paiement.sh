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

PAIEMENT_ID="${1:-}"
SOCIETE_ID="${2:-}"
TOLERANCE="${3:-}"

if [[ -z "${PAIEMENT_ID}" ]]; then
  echo "Usage: $0 <paiement_id> [societe_id] [tolerance]"
  exit 1
fi

ARGS=( -v "paiement_id=${PAIEMENT_ID}" )
if [[ -n "${SOCIETE_ID}" ]]; then
  ARGS+=( -v "societe_id=${SOCIETE_ID}" )
fi
if [[ -n "${TOLERANCE}" ]]; then
  ARGS+=( -v "tolerance=${TOLERANCE}" )
fi

cat scripts/workflow_rapprocher_paiement.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro "${ARGS[@]}"
