#!/usr/bin/env bash
set -euo pipefail

# Exemple: ./scripts/db_psql.sh -c "SELECT 1;"
# Exemple: ./scripts/db_psql.sh -f scripts/workflow_rapprocher_paiement.sql -v paiement_id=... -v societe_id=... -v tolerance=1
# Exemple: ./scripts/db_psql.sh -c "\i scripts/seed.sql"

docker compose exec -T db psql -U locatifpro -d locatifpro -v ON_ERROR_STOP=1 -X "$@"
