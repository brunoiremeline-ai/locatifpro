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

# Load local .env if present
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

echo "Applying Directus metadata (collections/fields/relations)..."
cat scripts/populate_directus_metadata.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro

echo "Applying UX defaults (display templates / relation interfaces)..."
cat scripts/ux_defaults.sql | "${DC[@]}" exec -T db psql -U locatifpro -d locatifpro

echo "Done. (Refresh Directus UI: F5)"
