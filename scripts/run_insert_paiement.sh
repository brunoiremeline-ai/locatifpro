#!/usr/bin/env bash
set -euo pipefail

REF="${1:-}"
MONTANT="${2:-}"
SOC="${3:-}"
DATE="${4:-}"
MODE="${5:-VIREMENT}"
COMM="${6:-}"

if [[ -z "$REF" || -z "$MONTANT" || -z "$SOC" ]]; then
  echo "Usage: $0 <reference> <montant> <societe_uuid> [date_YYYY-MM-DD] [mode] [commentaire]" >&2
  exit 2
fi

./scripts/db_psql.sh -qAt \
  -v ref="$REF" \
  -v montant="$MONTANT" \
  -v soc="$SOC" \
  -v date="$DATE" \
  -v mode="$MODE" \
  -v comm="$COMM" <<'SQL'
INSERT INTO paiements (reference_paiement, date_paiement, montant, societe_interne_id, mode_paiement, commentaire)
VALUES (
  :'ref',
  COALESCE(NULLIF(:'date','')::date, CURRENT_DATE),
  :montant::numeric,
  :'soc'::uuid,
  :'mode',
  NULLIF(:'comm','')
)
RETURNING id;
SQL
