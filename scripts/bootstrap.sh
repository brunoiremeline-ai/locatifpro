#!/usr/bin/env bash
set -euo pipefail

# Load local .env if present (ADMIN_EMAIL / ADMIN_PASSWORD / PUBLIC_URL, etc.)
# This keeps credentials consistent across reset/bootstrap.
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi


# Docker Compose: compat "docker compose" / "docker-compose"
if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose)
else
  echo "ERROR: Docker Compose introuvable (docker compose / docker-compose)."
  exit 1
fi

# --- Auto-config pour éviter les erreurs "d'entrée" ---
# 1) ADMIN_EMAIL : prend l'email Git si dispo/valide, sinon un fallback public
if [[ -z "${ADMIN_EMAIL:-}" ]]; then
  git_email="$(git config --get user.email 2>/dev/null || true)"
  if [[ -n "$git_email" && "$git_email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
    export ADMIN_EMAIL="$git_email"
  fi
fi
: "${ADMIN_EMAIL:=admin@example.com}"

# 2) PUBLIC_URL : détecte Codespaces, sinon localhost
if [[ -z "${PUBLIC_URL:-}" ]]; then
  if [[ -n "${CODESPACE_NAME:-}" && -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
    export PUBLIC_URL="https://${CODESPACE_NAME}-8055.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
  else
    export PUBLIC_URL="http://localhost:8055"
  fi
fi

# 3) ADMIN_PASSWORD : garde le défaut si non fourni
: "${ADMIN_PASSWORD:=Admin123!ChangeMe}"

# 4) ENABLE_RBAC : 0 par défaut (standby)
: "${ENABLE_RBAC:=0}"

# 1) Up
"${DC[@]}" up -d

# 2) Wait Directus health
echo "Waiting for Directus..."
ok="0"
for i in {1..60}; do
  if "${DC[@]}" exec -T directus node -e "require('http').get('http://localhost:8055/server/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1));" >/dev/null 2>&1; then
    echo "Directus is up."
    ok="1"
    break
  fi
  sleep 2
done

if [[ "$ok" != "1" ]]; then
  echo "ERROR: Directus n'a pas démarré (healthcheck KO)."
  echo "Dernières logs:"
  "${DC[@]}" logs --tail 120 directus || true
  exit 1
fi

# 3) Populate Directus metadata from Postgres schema (collections, fields, relations)
#    This is idempotent: uses NOT EXISTS to avoid re-inserting
echo "Ensuring dashboard cache tables exist (dash_*)..."
cat scripts/create_dash_tables.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro

echo "Populating Directus metadata from PostgreSQL schema..."
cat scripts/populate_directus_metadata.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro

# 4) Patch FK to directus_users (optional)
echo "Patching FK user_societes -> directus_users (if possible)..."
cat scripts/patch_directus_user_fk.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro

echo "Applying MCD consistency patch..."
cat scripts/patch_mcd_consistency.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro

echo "Ensuring explicit conflict message trigger for baux ACTIF..."
cat scripts/ensure_baux_conflict_message_trigger.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro

echo "Ensuring workflow function for echeances generation..."
cat scripts/workflow_generate_echeances_fn.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro

# 5) Create views and refresh metadata
./scripts/db_psql.sh < scripts/view_v_echeances_reste_a_payer.sql
./scripts/db_psql.sh < scripts/view_v_relances_bientot.sql
./scripts/db_psql.sh < scripts/view_v_paiements_reste_a_allouer.sql
./scripts/db_psql.sh < scripts/view_v_relances_a_faire.sql
./scripts/db_psql.sh < scripts/view_v_paiements_en_avance.sql
./scripts/db_psql.sh < scripts/view_v_kpi_societe.sql
echo "Refreshing Directus metadata (including views)..."
./scripts/db_psql.sh < scripts/populate_directus_metadata.sql

./scripts/directus_selfheal.sh

# 6) Apply UX modules in stable order (idempotent scripts)
#    Rule: metadata first, UX modules last.
UX_SCRIPTS=(
  "scripts/ux_defaults.sql"
  "scripts/ux_portefeuille.sql"
  "scripts/ux_baux.sql"
  "scripts/ux_echeances.sql"
  "scripts/ux_set_french.sql"
)

for ux_script in "${UX_SCRIPTS[@]}"; do
  echo "Applying UX module: ${ux_script}"
  cat "${ux_script}" | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro | grep -E "item_type|count|status|ux_.*_applied|^-"
done

echo "Ensuring main dashboard exists..."
./scripts/db_psql.sh < scripts/create_main_dashboard.sql
./scripts/db_psql.sh < scripts/create_baux_bulk_status_panel.sql

echo "Updating impaye_flag..."
./scripts/run_maj_impaye_flag.sh

# 7) Setup RBAC (Role-Based Access Control)
#    Create Agent role and permissions scoped by societe_interne
if [[ "${ENABLE_RBAC}" == "1" ]]; then
  echo "Setting up RBAC (Agent role and permissions)..."
  cat scripts/setup_rbac.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro | grep -E "item_type|count|^-"
else
  echo "RBAC step skipped (ENABLE_RBAC=0)."
fi

echo ""
echo "✅ Bootstrap complete."
echo "🔗 Login Directus: ${PUBLIC_URL}"
echo "👤 Admin: ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}"
echo "📖 Security model: https://github.com/ebrunoir-byte/locatifpro/blob/main/docs/security_model.md"
