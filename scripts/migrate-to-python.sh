#!/usr/bin/env bash
# Run from the demo repo root after phase-1 has synced successfully.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ ! -f values.lua ]]; then
  echo "values.lua already absent; nothing to migrate" >&2
  exit 1
fi

cp migrate/values.py values.py
rm -f values.lua

git add values.py values.lua
git status
git commit -m "$(cat <<'EOF'
migrate helm values generation from lua to python

Remove values.lua so a stale agent luaFile pointer fails with
"failed to read lua file values.lua" when the service cache is skewed.
EOF
)"

echo
echo "Committed migration. Push, then apply manifests/02-service-python.yaml"
echo "  git push"
echo "  kubectl apply -f manifests/02-service-python.yaml"
