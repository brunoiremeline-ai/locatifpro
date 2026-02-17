#!/usr/bin/env bash
set -euo pipefail

echo "== MAJ impaye_flag =="
cat scripts/workflow_maj_impaye_flag.sql | ./scripts/db_psql.sh
