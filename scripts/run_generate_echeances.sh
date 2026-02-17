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

START_DATE=""
END_DATE=""
BAIL_ID=""
START_PERIOD=""
PERIODS=""
MODE="skip"
INCLUDE_START="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start-date) START_DATE="${2:-}"; shift 2 ;;
    --end-date) END_DATE="${2:-}"; shift 2 ;;
    --bail-id) BAIL_ID="${2:-}"; shift 2 ;;
    --start-period) START_PERIOD="${2:-}"; shift 2 ;;
    --periods) PERIODS="${2:-}"; shift 2 ;;
    --include-start) INCLUDE_START="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    *)
      # Backward compatibility:
      #  - 2 positional args => start_date end_date
      #  - 1 positional arg => bail_id
      if [[ -z "$START_DATE" && -z "$BAIL_ID" && "$1" =~ ^[0-9a-fA-F-]{36}$ ]]; then
        BAIL_ID="$1"; shift
      elif [[ -z "$START_DATE" ]]; then
        START_DATE="$1"; shift
      elif [[ -z "$END_DATE" ]]; then
        END_DATE="$1"; shift
      else
        echo "ERROR: argument inconnu: $1" >&2
        exit 1
      fi
      ;;
  esac
done

PSQL_ARGS=()
if [[ -n "$START_DATE" ]]; then PSQL_ARGS+=(-v start_date="$START_DATE"); fi
if [[ -n "$END_DATE" ]]; then PSQL_ARGS+=(-v end_date="$END_DATE"); fi
if [[ -n "$BAIL_ID" ]]; then PSQL_ARGS+=(-v bail_id="$BAIL_ID"); fi
if [[ -n "$START_PERIOD" ]]; then PSQL_ARGS+=(-v start_period="$START_PERIOD"); fi
if [[ -n "$PERIODS" ]]; then PSQL_ARGS+=(-v periods="$PERIODS"); fi
if [[ -n "$INCLUDE_START" ]]; then PSQL_ARGS+=(-v include_start="$INCLUDE_START"); fi
PSQL_ARGS+=(-v mode="$MODE")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FN_FILE="$SCRIPT_DIR/workflow_generate_echeances_fn.sql"
SQL_FILE="$SCRIPT_DIR/workflow_generate_echeances.sql"

if [[ ! -f "$SQL_FN_FILE" ]]; then
  echo "ERROR: SQL function file not found: $SQL_FN_FILE" >&2
  exit 1
fi
if [[ ! -f "$SQL_FILE" ]]; then
  echo "ERROR: SQL file not found: $SQL_FILE" >&2
  exit 1
fi

PGUSER="${POSTGRES_USER:-locatifpro}"
PGDB="${POSTGRES_DB:-locatifpro}"

cat "$SQL_FN_FILE" | "${DC[@]}" exec -T db psql -U "$PGUSER" -d "$PGDB"
cat "$SQL_FILE" | "${DC[@]}" exec -T db psql -U "$PGUSER" -d "$PGDB" "${PSQL_ARGS[@]}"
