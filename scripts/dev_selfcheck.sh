#!/usr/bin/env bash
set -euo pipefail

echo "== Git pager =="
git config --local --get core.pager || true

echo "== db_psql runner =="
test -x scripts/db_psql.sh && echo "OK: scripts/db_psql.sh executable" || (echo "ERROR: scripts/db_psql.sh missing or not executable"; exit 1)

echo "== Directus safety =="
echo "Rappel: ne jamais modifier directus_* à la main. Si UI cassée: ./scripts/reset.sh && ./scripts/bootstrap.sh"
