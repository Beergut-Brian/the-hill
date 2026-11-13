#!/usr/bin/env bash
# Real screenshots without a monitor, so lanes can check their own visuals.
#   scripts/tools/shots.sh [scene.tscn] [times] [out_dir] [game args...]
#   scripts/tools/shots.sh res://scenes/levels/field.tscn 1,3,6 /tmp/shots
# Menus: pass --ui=<state> (lobby, lobby-joined, lobby-ready, lobby-hold, lobby-settings,
# lobby-confirm, lobby-refuse, pause, pause-settings, pause-confirm, pause-door, pause-refuse; scenes/ui/kit/ui_preview.gd):
#   scripts/tools/shots.sh "" 1.5 /tmp/shots --ui=pause-settings
# Uses `godot-render` (virtual X display + Mesa software Vulkan, Forward+) when it exists, else a real
# display if $DISPLAY/$WAYLAND_DISPLAY is set. Headless Godot has no renderer, so it can't take real shots.
set -euo pipefail
SCENE="${1:-}"; TIMES="${2:-1,3,6}"; OUT="${3:-$PWD/shots}"; shift $(( $# < 3 ? $# : 3 ))
mkdir -p "$OUT"
if command -v godot-render >/dev/null; then RUN=godot-render
elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then RUN=godot
else echo "shots.sh: no renderer here (no godot-render, no display)" >&2; exit 2; fi
"$RUN" --path . --resolution 1920x1080 ${SCENE:+"$SCENE"} -- --shots="$TIMES" --shot-dir="$OUT" "$@" 2>&1 \
  | grep -E "^screenshot:|Forward|Compatibility|SCRIPT ERROR|ERROR" | grep -v fontconfig || true
ls -1 "$OUT"/*.png
