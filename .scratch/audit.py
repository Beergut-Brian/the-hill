import re, os, subprocess, sys
root = '.'
def show(path): return subprocess.run(['git','show','origin/dev:'+path],capture_output=True,text=True).stdout
cues_md = show('assets/audio/CUES.md'); game = show('GAME.md'); audio = show('scripts/autoload/Audio.gd')
aliases = dict(re.findall(r'"(\w+)":\s*"(\w+)"', audio[audio.find('const ALIASES'):audio.find('const DEFAULT_CAP')]))
files = subprocess.run(['git','ls-tree','-r','--name-only','origin/dev'],capture_output=True,text=True).stdout.split()
sfx = {os.path.basename(f) for f in files if f.startswith('assets/audio/sfx/')}
src = [f for f in files if re.match(r'(scripts|scenes|data)/', f) and f != 'scripts/autoload/Audio.gd' and f.endswith(('.gd','.tres','.tscn'))]
blobs = {f: show(f) for f in src}
cue_rows = re.findall(r'^\| (\w+) \| (sfx/[^|]+)\|', cues_md, re.M)
game_tbl = game[game.find('## Audio'):game.find('## Technical plan')]
game_cues = []
for cell in re.findall(r'^\| ([^|]+) \|', game_tbl, re.M):
    game_cues += re.findall(r'`([\w<>]+)`', cell)
vehicles = ['front_loader','excavator','dump_truck','crane','drill_rig']
blocks = ['dirt','clay','stone','ice','crystal']
exp = []
for c in game_cues:
    if c == 'engine_<vehicle>': exp += ['engine_'+v for v in vehicles]
    elif c == 'horn_<vehicle>': exp += ['horn_'+v for v in vehicles] + ['dump_truck_reverse']
    elif c == 'dig_<block>': exp += ['dig_'+b for b in blocks]
    else: exp.append(c)
def has_file(n):
    return any(re.fullmatch(re.escape(n)+r'(_\d+)?\.(ogg|wav)', s) for s in sfx)
def sites(n):
    pat = re.compile(r'["&]' + re.escape(n) + r'"')
    hits = []
    for f,b in blobs.items():
        for i,l in enumerate(b.splitlines(),1):
            if pat.search(l): hits.append(f'{f}:{i}')
    return hits
rows = []
seen = set()
for src_name, names in (('GAME.md', exp), ('CUES.md', [c for c,_ in cue_rows])):
    for n in names:
        if (src_name, n) in seen: continue
        seen.add((src_name,n))
        r = aliases.get(n, n)
        f = has_file(r)
        s = sites(r) + (sites(n) if r != n else [])
        rows.append((src_name, n, r, f, s))
print('| From | Cue | Plays as | File on dev | Call site on dev | Played on dev |')
print('| --- | --- | --- | --- | --- | --- |')
for src_name,n,r,f,s in rows:
    print(f"| {src_name} | {n} | {r if r!=n else ''} | {'yes' if f else 'NO'} | {', '.join(s[:2]) + (' +%d'%(len(s)-2) if len(s)>2 else '') if s else 'NONE'} | {'yes' if f and s else 'NO'} |")
