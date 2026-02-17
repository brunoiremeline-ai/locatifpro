#!/usr/bin/env bash
set -euo pipefail

# Dev setup (local repo only)
git config --local core.pager cat
echo "OK: git pager disabled (core.pager=cat)"
