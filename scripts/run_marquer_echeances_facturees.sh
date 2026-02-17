#!/usr/bin/env bash
set -euo pipefail

# Docker Compose: compat "docker compose" / "docker-compose"
if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose)
else
  echo "ERROR: Docker Compose introuvable (docker compose / docker-compose)." >&2
  exit 1
fi

# Load local .env if present
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

AS_OF_DATE="${1:-}"
BAIL_ID="${2:-}"
SOCIETE_ID="${3:-}"

PSQL_ARGS=()
if [[ -n "$AS_OF_DATE" ]]; then PSQL_ARGS+=(-v as_of_date="$AS_OF_DATE"); fi
if [[ -n "$BAIL_ID" ]]; then PSQL_ARGS+=(-v bail_id="$BAIL_ID"); fi
if [[ -n "$SOCIETE_ID" ]]; then PSQL_ARGS+=(-v societe_interne_id="$SOCIETE_ID"); fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/workflow_marquer_echeances_facturees.sql"

PGUSER="${POSTGRES_USER:-locatifpro}"
PGDB="${POSTGRES_DB:-locatifpro}"

cat "$SQL_FILE" | "${DC[@]}" exec -T db psql -U "$PGUSER" -d "$PGDB" "${PSQL_ARGS[@]}"
