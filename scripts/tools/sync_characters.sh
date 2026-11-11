#!/usr/bin/env bash
# Vendor the playable characters from openjar-characters into this game.
#   scripts/tools/sync_characters.sh <characters-repo-path> <tag>
#   scripts/tools/sync_characters.sh ~/openjar/openjar-characters v0.3.0
# For every id in the tag's characters.json "roster" it copies the runtime files into
# assets/characters/<id>/:
#   <id>.glb          the 3D master (model_3d); Godot extracts its face/cloth textures on import
#   pixel.png         the pixel form at native size, drawn by the library's own sprite code
#                     (needs python3 + Pillow; skipped with a warning without them)
#   voice/*.ogg       the voice barks, if any are recorded yet
#   voice/catchphrase.ogg  the chooser's catchphrase: voice/lib/catchphrase_big.ogg only (nothing
#                     else from lib/, to keep exports small); not a bark
# then writes data/roster.json (roster order, names, defaults, player colours, res:// paths, the
# tag) and the characters block in assets/CREDITS.md. Folders of ids no longer in the roster are
# removed. Rerun it with a new tag to pick up new characters: no code change.
# SYNC_CHARACTERS_ROOT=<dir> writes into another project (the tests use it).
# Reads the tag with `git show`, so the characters checkout can be on any branch.
set -euo pipefail
if [[ $# -ne 2 ]]; then
	echo "usage: $0 <characters-repo-path> <tag>" >&2
	exit 2
fi
LIB="$(cd "$1" && pwd)"
TAG="$2"
ROOT="$(cd "${SYNC_CHARACTERS_ROOT:-$(dirname "${BASH_SOURCE[0]}")/../..}" && pwd)"
git -C "$LIB" rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
	|| { echo "sync_characters: no tag $TAG in $LIB" >&2; exit 1; }
WORK="$ROOT/.scratch/sync_characters.$$"
mkdir -p "$WORK/pixel"
trap 'rm -rf "$WORK"' EXIT
git -C "$LIB" show "$TAG:characters.json" > "$WORK/characters.json"
git -C "$LIB" ls-tree -r --name-only "$TAG" > "$WORK/files.txt"
for f in $(grep '^tools/pixel/.*\.py$' "$WORK/files.txt" || true); do
	git -C "$LIB" show "$TAG:$f" > "$WORK/pixel/$(basename "$f")"
done

python3 -I - "$LIB" "$TAG" "$ROOT" "$WORK" <<'PY'
import json, os, re, shutil, subprocess, sys

lib, tag, root, work = sys.argv[1:5]
index = json.load(open(os.path.join(work, "characters.json")))
files = set(open(os.path.join(work, "files.txt")).read().split("\n"))
by_id = {c["id"]: c for c in index["characters"]}
out_dir = os.path.join(root, "assets", "characters")
os.makedirs(out_dir, exist_ok=True)


def show(path, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    blob = subprocess.run(["git", "-C", lib, "show", f"{tag}:{path}"], capture_output=True, check=True).stdout
    if blob.startswith(b"version https://git-lfs"):
        # The library keeps binaries in Git LFS: turn the pointer into the file.
        blob = subprocess.run(["git", "-C", lib, "lfs", "smudge", "--", path], input=blob,
                              capture_output=True, check=True).stdout
        if blob.startswith(b"version https://git-lfs"):
            sys.exit(f"sync_characters: {path} is not fetched; run git lfs pull in {lib}")
    with open(dest, "wb") as f:
        f.write(blob)


def pixel_png(c, dest):
    px = c.get("pixel") or {}
    src, fn = px.get("source", ""), px.get("function", "")
    if not src or not fn or src not in files or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", fn):
        return False
    code = ("import sys; sys.path.insert(0, sys.argv[1]); import importlib; "
            "m = importlib.import_module(sys.argv[2]); getattr(m, sys.argv[3])().save(sys.argv[4])")
    mod = os.path.splitext(os.path.basename(src))[0]
    r = subprocess.run([sys.executable, "-I", "-c", code, os.path.join(work, "pixel"), mod, fn, dest],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"sync_characters: warning: no pixel form for {c['id']} ({r.stderr.strip().splitlines()[-1:]})",
              file=sys.stderr)
        return False
    return True


roster, chars, credits = [], {}, []
for cid in index.get("roster", []):
    c = by_id.get(cid)
    if not c or not c.get("playable"):
        print(f"sync_characters: skipping {cid}: not a playable character", file=sys.stderr)
        continue
    d = os.path.join(out_dir, cid)
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    res = f"res://assets/characters/{cid}/"
    entry = {"name": c["name"], "glb": "", "pixel": "", "voice": "", "barks": [], "catchphrase": "",
             "default_for": c.get("default_for") or 0}
    if c.get("model_3d") and c["model_3d"] in files:
        show(c["model_3d"], os.path.join(d, f"{cid}.glb"))
        entry["glb"] = res + f"{cid}.glb"
        credits.append((f"characters/{cid}/{cid}.glb", f"`openjar-characters` `{tag}`, `{c['model_3d']}` "
                        "(Jarlings avatar kit, Blender, procedural); Godot extracts its textures "
                        f"(`{cid}_*.png`) on import", f"{c['name']}, playable; copied unchanged"))
    if pixel_png(c, os.path.join(d, "pixel.png")):
        entry["pixel"] = res + "pixel.png"
        credits.append((f"characters/{cid}/pixel.png", f"`openjar-characters` `{tag}`, "
                        f"`{c['pixel']['source']}` `{c['pixel']['function']}()` (Python + Pillow, drawn in code)",
                        f"{c['name']} pixel form ({c['pixel'].get('alt_form', 'pixel')}), front view, native size"))
    voice = (c.get("voice") or "").rstrip("/") + "/"
    oggs = sorted(f for f in files if f.startswith(voice) and f.endswith(".ogg") and "/" not in f[len(voice):])
    for f in oggs:
        show(f, os.path.join(d, "voice", os.path.basename(f)))
    if oggs:
        entry["voice"] = res + "voice/"
        entry["barks"] = [os.path.splitext(os.path.basename(f))[0] for f in oggs]
        credits.append((f"characters/{cid}/voice/*.ogg", f"`openjar-characters` `{tag}`, `{voice}`",
                        f"{c['name']} voice barks: {', '.join(entry['barks'])}; see the library's CREDITS.md"))
    phrase = voice + "lib/catchphrase_big.ogg"
    if voice != "/" and phrase in files:
        show(phrase, os.path.join(d, "voice", "catchphrase.ogg"))
        entry["catchphrase"] = res + "voice/catchphrase.ogg"
        credits.append((f"characters/{cid}/voice/catchphrase.ogg", f"`openjar-characters` `{tag}`, `{phrase}`",
                        f"{c['name']} catchphrase (the chooser says it); see the library's CREDITS.md"))
    roster.append(cid)
    chars[cid] = entry

for name in sorted(os.listdir(out_dir)):
    p = os.path.join(out_dir, name)
    if os.path.isdir(p) and name not in roster:
        shutil.rmtree(p)
        print(f"sync_characters: removed {name} (no longer in the roster)")

data = {
    "source": "openjar-characters",
    "characters_tag": tag,
    "roster": roster,
    "defaults": index.get("defaults", {}),
    "player_colours": index.get("player_colours", {}),
    "characters": chars,
}
os.makedirs(os.path.join(root, "data"), exist_ok=True)
with open(os.path.join(root, "data", "roster.json"), "w") as f:
    json.dump(data, f, indent="\t")
    f.write("\n")

lic = "Open Jar Games, in-house (same terms as openjar-characters)"
block = ["<!-- characters:begin (scripts/tools/sync_characters.sh writes this block) -->", "",
         f"## Characters (synced from openjar-characters {tag})", "",
         "| File | Source / tool | Prompt or notes | License |", "| --- | --- | --- | --- |"]
block += [f"| `{a}` | {b} | {n} | {lic} |" for a, b, n in credits]
block += ["", "<!-- characters:end -->"]
cp = os.path.join(root, "assets", "CREDITS.md")
text = open(cp).read()
m = re.search(r"<!-- characters:begin.*?<!-- characters:end -->", text, re.S)
text = text[:m.start()] + "\n".join(block) + text[m.end():] if m else text.rstrip("\n") + "\n\n" + "\n".join(block) + "\n"
open(cp, "w").write(text)
print(f"sync_characters: {tag}: {', '.join(roster)} -> assets/characters/, data/roster.json")
PY
