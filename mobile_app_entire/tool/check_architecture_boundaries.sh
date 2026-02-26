#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

search() {
  local pattern="$1"
  local target="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$target"
    return $?
  fi
  grep -R -n -E "$pattern" "$target"
}

echo "[boundary] checking domain imports"
if search "^import 'package:(flutter|flutter_riverpod|dio|drift|go_router|file_picker|fl_chart)" lib/domain; then
  echo "[boundary] ERROR: domain layer imports forbidden framework packages"
  exit 1
fi

if search "^import 'package:mobile_app_entire/(data|features|app|shared)/" lib/domain; then
  echo "[boundary] ERROR: domain depends on outer layers"
  exit 1
fi

echo "[boundary] checking application imports"
if search "^import 'package:mobile_app_entire/(data|features)/" lib/application; then
  echo "[boundary] ERROR: application depends on data/features"
  exit 1
fi

echo "[boundary] passed"
