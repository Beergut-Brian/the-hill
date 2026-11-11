#!/usr/bin/env bash
# Rebuilds store/jar.glb (the launcher's jar world) from art/tools/make_jar.py with Blender 5.2.3.
#   art/tools/make_jar.sh [out.glb]
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="$(realpath -m "${1:-store/jar.glb}")"
blender --background --factory-startup --python art/tools/make_jar.py -- "$OUT" 2>&1 \
  | grep -E "^make_jar:|Error|Traceback|^  File" || true
test -s "$OUT"
