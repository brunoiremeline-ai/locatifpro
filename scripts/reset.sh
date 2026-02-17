#!/usr/bin/env bash
set -euo pipefail

# By default, keep volumes/data.
# Use --volumes (or -v) for a full destructive reset.
REMOVE_VOLUMES=0
if [[ "${1:-}" == "--volumes" || "${1:-}" == "-v" ]]; then
  REMOVE_VOLUMES=1
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

if [[ "$REMOVE_VOLUMES" -eq 1 ]]; then
  "${DC[@]}" down -v
  echo "Containers stopped and volumes removed (destructive reset)."
else
  "${DC[@]}" down
  echo "Containers stopped (data volumes preserved)."
fi
