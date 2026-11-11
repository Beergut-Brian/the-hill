#!/usr/bin/env bash
# Store art rendered from the real game (art/store/store_shot.tscn), per GAME.md "Store art":
#   store/grid.png (600x900): the centre of a 1080p frame, cropped 2:3 and scaled.
#   store/hero.png (920x430): a 1080p frame cropped to 2.14:1 and scaled.
#   art/tools/render_store.sh [out_dir]    (default store/; raw frames are kept in out_dir/raw only if RAW=1)
# Needs a renderer (godot-render or a display), an imported project, and python3 with Pillow.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="$(realpath -m "${1:-store}")"
mkdir -p "$OUT"
if command -v godot-render >/dev/null; then RUN=godot-render
elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then RUN=godot
else echo "render_store.sh: no renderer here" >&2; exit 2; fi
[[ -d .godot ]] || godot --headless --path . --import >/dev/null 2>&1
TMP="$PWD/.scratch/store_raw"
mkdir -p "$TMP"
for shot in grid hero; do
  rm -f "$TMP/$shot.png"
  timeout 180 "$RUN" --path . --resolution 1920x1080 res://art/store/store_shot.tscn -- --shot=$shot --out="$TMP/$shot.png" 2>&1 \
    | grep -E "^store:|SCRIPT ERROR" || true
  test -s "$TMP/$shot.png"
done
python3 -I - "$TMP" "$OUT" <<'PY'
import sys
from PIL import Image
tmp, out = sys.argv[1], sys.argv[2]
g = Image.open(f"{tmp}/grid.png").convert("RGB")
g.crop((600, 0, 1320, 1080)).resize((600, 900), Image.LANCZOS).save(f"{out}/grid.png")
h = Image.open(f"{tmp}/hero.png").convert("RGB")
h.crop((0, 91, 1920, 988)).resize((920, 430), Image.LANCZOS).save(f"{out}/hero.png")
print("store: wrote grid.png 600x900, hero.png 920x430 to", out)
PY
