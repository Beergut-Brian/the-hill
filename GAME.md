# The Hill

> Design doc and source of truth for this game. Gary (the producer) owns this file. Lanes read it before
> starting and quote it in PRs. If the game drifts from this doc, fix the doc or fix the game.
> Source: Kaden's plan "The Hill — Game Design & Build Plan" (2026-11-09), kept nearly verbatim below,
> with the producer notes in the next section taking precedence where they differ.

## Producer notes (these supersede the plan text below where they differ)

- **Game order:** The Hill is **game 3** (Kaden, 2026-11-09: Spaceballs, Junk Yard Zap, The Hill, Life of a Worm, Smash Party rebuild, maybe Castle Defense). Its foundation (Phase 0 and Phase 1) runs **now**, overnight, in parallel with Junk Yard Zap.
- **Premium model = Fable 5.2 on Kaden's Max plan** (Claude Code login, model `claude-fable-5-2`, no API key), as a **director** that designs and reviews while **Opus worker subagents** build. "Premium budget" figures below are tracked as Claude Code's API-equivalent estimates (it prices Fable at Opus rates, so the real figure is about 2x what it prints); slice spend is logged here by the producer.
- **Template features every game has:** grown-up menus (main menu/lobby with text, pause with blur, settings, leave confirm; `docs/ui.md`), solo playtest mode, `--demo`, `--shots=`, release smoke-boot, `store/jar.glb` launcher jar world. Customise template UI in code in `_ready()`, never as `.tscn` overrides on instanced template children (exports drop them).
- **No personal info or real places, ever.**
- **Art (Kaden, 2026-11-10, D45):** palette A "Sandbox" is the baseline; A, B and C are kept as references for a **day/night cycle** (day, dusk, night as a palette shift). A second art-direction round explores two visually distinct styles (one Terraria-leaning) before final art. **Construction vehicles have no eyes or faces** (supersedes "faces in the headlights").
- **Life of a Worm reuse is a design requirement:** the tile world (chunks, edit-only saves, falling bodies, water fill), the dynamic split director and `PictoBubble` are written as game-agnostic modules from day one, with gravity as a function and the chunk key abstracted, so Worm's polar disk is a swap. See `~/openjar/WORM-READINESS.md` (producer's ledger).
- **Characters:** this game is 2D pixel art, while Jeff and Chuck exist as 3D Jarlings. The library gains a 2D pixel format for them and the four new residents (look sheets, sprite sheets); bibles go in `openjar-characters` first.

## Pitch

Jeff and Chuck inherit a hill with a hole in it and a Front Loader parked out front. Dig down in big satisfying chunks, find treasure and weird stuff (fossils, a buried car, a dragon egg, a room full of gnomes), haul it up, and build the town of **Hillville** on top with the blocks you dug. Every building you place makes the digging better: a garage unlocks the next construction vehicle, a lighthouse lights the next layer down, a gnome village sends gnomes to dig for you overnight. The hill has a bottom, and something is sleeping down there.

Two scenes, one loop: **down** is a 2D pixel-art tile world streamed in chunks; **up** is a side-view town where you clear land with vehicles and snap prefab buildings into place. One of you can be forty layers down while the other builds a hundred barns, and the screen splits and re-joins on its own.

Repo: `Beergut-Brian/the-hill` (from `openjar-template`). Build order: game 3, before Life of a Worm, because its underground engineering (chunked diggable world, edit-only saves, falling debris, breakable structures) is Worm's head start and only transfers if this game is 2D tiles.

**Kaden's original notes, kept verbatim as the north star**

- Dig & build sandbox: two players dig down, find treasure, build up. Chunked world.
- Soft goal: the hill has a bottom, and something is down there.
- Prefab building, not individual blocks.
- New library characters: yes, dive in.
- We go down and collect stuff, then come up and build a town around the hill. He still chooses what buildings go where; we just give him options. If he wants 100 barns, so be it.
- He loves construction vehicles, so make that part of it. He has to clear the land above in order to build. The hill comes with a Front Loader or something.
- Going underground is a cutscene, separated from up top. One player up top, the other below: true split screen. If both are visible on one screen, the split disappears.
- Game name: The Hill. Town name: Hillville.

## Players and cast

Jeff (P1, green) and Chuck (P2, red) own the hill. Four new universal characters make their library debut here and are proposed for Kaden's approval; bibles go in `openjar-characters` before any art is made.

| Character | Kind | Role in The Hill | Proposed personality |
| --- | --- | --- | --- |
| **Jeff** | player-locked P1 | Owner, digger, builder. Hard hat over the chicken costume | As ever: delighted. Names every rock he digs up |
| **Chuck** | player-locked P2 | Owner, digger, builder. Hard hat replaces the trucker hat; he is not happy about it | Treats the Front Loader like a sports car. Insists he is the foreman |
| **The Mole** | universal, new | Lives in the dirt. Steals your shovel, pops up somewhere else, apologises, gives it back. After three thefts he comes to the surface to better himself; restore the Old Shed and he runs the Lost & Found | Nearsighted, polite, deeply embarrassed by his own kleptomania. Squints. Says "oh dear" a lot |
| **The Gnome Foreman** | universal, new | Found in a buried gnome room around layer 6. Once you build the Gnome Village, he runs a crew that digs while you are away | Tiny hard hat, clipboard, very serious, treats a 5-year-old's instructions as binding contracts. Blows a whistle |
| **The Dragon** | universal, new | Asleep at the bottom of the hill, curled around the last treasure. The soft goal is reaching her. Once woken she is enormous, sleepy and wants to be friends; she moves to the top of Hillville and becomes its landmark | Slow, yawning, speaks in rumbles. Likes being built on. Warms the town in winter (cosmetic) |

**The Caveman** (universal, new) is the fourth debut: frozen in the Ice layer, he thaws, waves, and follows you up. Restore the Flooded Cabin and he becomes the Museum's curator. Proposed personality: delighted and baffled by everything modern, polishes treasures constantly, communicates in grunts and enthusiastic pointing. All four residents have a redemption arc; see Residents: the ruins.

**Co-op.** Both players share one inventory (a block pile at the mine shaft) and one town. No ownership of blocks or buildings. You can be in different scenes at once; the camera handles it (see Camera).

**Drop-in.** The second player's character is asleep in the Front Loader's bucket; a button press tips him out.

## The loop

**Dig to get stuff → build Hillville with stuff → Hillville makes digging better → dig deeper.** It is one machine, not a digger and a town builder glued together: every building type feeds something back underground, and every vehicle works in both worlds.

**A typical session (10 to 20 minutes, saves at every trip up)**

1. Load in. Hillville is as you left it; the gnome crew has dug a little overnight and left a pile at the shaft.
2. Drive the Front Loader to the mine shaft, step in, the elevator drops: cut to underground at your deepest layer.
3. Dig. Big chunks, three tiles per swing by now. Blocks fly into the backpack with a pop. You hit a fossil: it sparkles, he squeals, it goes in the treasure bag. The Mole steals your shovel, pops up two tunnels over, apologises.
4. Backpack full (it is never a hard stop: the icon just goes round and happy). Ride the elevator up: cut to Hillville. Dump at the shaft pile.
5. Open the build book (one button). Pictures of buildings with a block cost shown as a stack of block icons, greyed if you cannot afford it. He picks a barn. Again. Again. Kaden picks the Garage.
6. Drive to a cleared plot, drop the building; it snaps to the ground grid, unfolds with a satisfying clunk. The Garage opens its door: an Excavator rolls out. New vehicle.
7. Repeat. Each trip down goes deeper and faster; each trip up grows the town. The soft goal pulls: the lighthouse lights a new layer, the Dragon's snore gets louder as you go.

**Two kinds of stuff come up**

| Stuff | What it is | What it is for |
| --- | --- | --- |
| **Blocks** | dirt, clay, stone, sand, ice, crystal (by depth) | Currency for buildings. Deeper blocks are worth more and some buildings need a specific kind |
| **Treasures** | one-of-a-kind finds: fossils, a buried car, a dragon egg, the gnome room, a giant tooth, a pirate chest | Each unlocks one specific thing (the gnome room unlocks the Gnome Village; the car unlocks the Garage) and then goes on display in the Museum |

**No fail state.** Nothing underground can hurt you. Water floods a tunnel and floats you back up, giggling. A cave-in buries you to the neck and the Mole digs you out. Dropping into a hole just means you are somewhere new. The town cannot be damaged; buildings can be picked up and moved for free.

## Two depths: simple for him, deep for Kaden

Spaceballs is deliberately a toy. The Hill is the library's one systems game, and it has to be fun for both players at once. The rule: **his layer is actions, Kaden's layer is consequences.** Everything he does (dig, drive, snap a building, pet the Dragon) is fun on its own and requires understanding nothing. Kaden's depth comes from systems interacting, and it is surfaced only as outcomes he can see (more gnomes marching, a bigger sparkle, water draining), never as stats, text or menus.

| Where the depth lives | What Kaden is doing | What his son sees |
| --- | --- | --- |
| **Logistics** | Deeper buildings need deeper blocks; hauling capacity (backpack, Dump Truck, gnome crew) is a real constraint; planning trips and routes | A truck ride and a big pile at the shaft |
| **Underground engineering** | Drain or redirect water to reach a treasure; drop a boulder by digging under it to break a wall you cannot dig yet; route around blocks that need a vehicle you do not have | Splashes, a boulder going bonk, a sparkle appearing |
| **Town adjacency (invisible)** | Buildings interact when placed near each other: barns beside the Gnome Village mean the crew hauls more; the Water Tower beside the pond drains faster; the Lighthouse on the peak lights an extra layer; the Museum beside the shaft makes the Mole find treasure more often | Little hearts float between buildings that like each other. A hundred random barns is still fine |
| **Collection** | The Museum shows treasures remaining per layer; the Mole's glow finds them; Strangestone at the bottom is a question only an adult notices | A full shelf and a curious wall |
| **Co-op division of labour** | One digs with the Drill Rig while the other hauls with the Dump Truck and builds; the loop runs faster when the two roles split | Driving the truck to meet Dad at the shaft |

**Guardrails**

- Nothing in Kaden's layer is ever required. The Dragon is reachable by pure digging and random building.
- No text, numbers or tooltips are added for the adult layer. Adjacency shows as hearts, output shows as bigger piles, puzzles show as water and boulders.
- Adult systems never punish. Bad placement means no bonus, never a penalty. A flooded tunnel floats you up; it never costs anything.
- Every adult system has to pass the kid test: if he stumbles into it by accident, it must still read as a fun thing that happened.
- Adjacency rules, block requirements and hazard placements are Content lane data (`data/adjacency.tres`, `BuildingData.needs_blocks`, `LayerData.hazards`), so Kaden's layer can be tuned from playtests without touching his son's.

## The loop at a glance

&#91;embedded content: the loop · dig, haul, build, feed back\]

The test for any new building or vehicle: name what it gives back to the dig. If the answer is "nothing, it is just nice" (the House), that is allowed for charm, but the majority must close the loop.

## Underground

A 2D tile world under the hill, about 200 tiles wide and 300 deep at 16 px tiles, streamed in chunks, every tile diggable. It is the same tile engine Life of a Worm will use, which is why this game comes first.

| Layer | Depth | Blocks | Treasures | Comedy hazards | Light |
| --- | --- | --- | --- | --- | --- |
| Topsoil | 0 to 30 | dirt, roots, worms (they wave) | bottle caps, a boot, a bike | the Mole steals your shovel | daylight bleeds in |
| Clay | 30 to 70 | clay, pebbles, old pipes | a buried car, a bathtub, fossils | water pockets flood and float you up | dim; headlamp |
| Stone | 70 to 130 | stone, ore veins, geodes | the Gnome Room, a giant tooth, a dinosaur skeleton | rolling boulders (bonk, stars, fine) | dark; needs the Lighthouse |
| Ice | 130 to 190 | ice (slippery), snow, frozen fish | a frozen caveman who wakes up and waves, a pirate chest | slide into holes | blue glow |
| Crystal | 190 to 260 | crystal (worth the most), lava pockets (bounce you, no damage) | the Dragon Egg | lava bounces | self-lit |
| The Bottom | 260 to 300 | a huge cavern | the Dragon, asleep, curled around the last treasure | her snore shakes the screen | warm |

- **Digging** is directional: hold a direction and the dig button, and the tool removes a shape (1 tile with the shovel, 3-wide with the Excavator, 5-wide with the Drill Rig). Removed tiles pop into the backpack. Big chunks, big sounds.
- **Loose things fall** when the ground under them goes: boulders, treasures, the bathtub, the Mole. This is a core engine feature Worm reuses.
- **Buildings and props break into chunks** when dug under: the car, the gnome room's walls.
- **Tunnels persist.** Only edits are saved (the base world comes from a seed), so the save stays small. Worm reuses this too.
- **Light** is a soft gate rather than a wall: deeper layers are dark until the Lighthouse (and its upgrades) light them. You can still dig in the dark; you just cannot see the treasure sparkle.
- **The bottom reveal.** Reaching the cavern triggers the one cutscene in the game: the Dragon yawns awake, the whole hill shakes, she asks (in rumbles and pictures) to come up top. The elevator carries her up in pieces (comedy). She coils around the hill's peak and Hillville has a dragon. The game continues; the hill is yours.

  **World borders (decided 2026-11-09).** The hill is bigger than v1 lets you dig.

  | Border | Block | Look | Breakable in v1 | Why |
  | --- | --- | --- | --- | --- |
  | Below the Dragon's cavern | **Strangestone**: a distinct, slightly animated tile (faint runes, a slow pulse) | Clearly not dirt; the kind of thing he will ask about | No. Shovels bounce off with a sparkle and a question-mark bubble | A second, stranger set of layers lives here in a later update; the reveal is already planted |
  | Left and right edges | **Edgestone**: plain, flat grey block with a simple hazard-stripe edge | Obviously "the edge", not mysterious | No. Later removable in data to expand outward | Keeps the world finite for streaming and saves; expansion is a data change, not a rewrite |

  Both are `BlockData` entries with `breakable = false` and a `breakable_from_version` field, so unlocking them later is a data edit.

## Up top: Hillville

A side-view town on and around the hill, about eight screens wide. It starts as scrub: trees, rocks, stumps, a rusty fence, and the mine shaft with the Front Loader beside it. You clear land to make plots, then snap prefab buildings onto plots. He chooses what goes where; the game never says no.

**Clearing land.** Trees, rocks and stumps are surface tiles. The Front Loader's bucket scoops them (they become blocks, so the surface is a shallow dig) and leaves a flat plot. Bigger vehicles clear bigger areas. Clearing is its own fun: the Loader has a horn, trees fall with a creak and a thump, rocks crack.

**Building.** One button opens the build book: a page of building pictures with their block cost drawn as stacked block icons, greyed if you are short. Pick one, a ghost follows your vehicle, drop it on a cleared plot and it snaps to the ground grid and unfolds with a clunk. Buildings can be picked up and moved for free. Place a hundred barns; the game cheers every time.

| Building | Cost (blocks) | What it does for the dig | What it does in town |
| --- | --- | --- | --- |
| **Barn** | 10 dirt | +1 backpack size per barn, no cap. A hundred barns is a very big backpack | Cows wander out. More barns, more cows |
| **House** | 15 dirt, 5 clay | Nothing mechanical | Jeff and Chuck sleep here; lights come on at dusk. Pure charm |
| **Garage** | 20 clay, 10 stone (needs the Buried Car) | Unlocks the next vehicle each time you build one (see Vehicles) | Vehicles park here with a door that opens |
| **Workshop** | 15 stone | Bigger shovel for on-foot digging; faster vehicles | Hammering sounds, sparks |
| **Lighthouse** | 20 stone, 5 crystal | Lights the next layer down; each one built lights one more | Sweeps a beam at night |
| **Museum** | restore the Flooded Cabin (see Residents) | Displays every treasure found; shows how many are left per layer | The Caveman's home; his trophy shelf |
| **Gnome Village** | restore the Crooked Watchtower (see Residents) | The Gnome Foreman's crew digs 20 to 50 blocks while the game is closed, up to a cap, and leaves them at the shaft | Tiny houses, tiny lights, a tiny whistle at shift change |
| **Water Tower** | 15 stone, 10 ice | Drains flooded tunnels faster | A generic small-town water tower; no real-place references anywhere in the public build |
| **Dragon Perch** | restore the Ruined Keep (see Residents) | The Dragon warms the ice layer so it is not slippery | The Dragon curls on it and snores. The town is complete |

**The Gnome crew** is the come-back-tomorrow hook. Build the village and the Foreman reports for duty: when you launch the game after being away, there is a pile at the shaft and a short clip of gnomes marching out of the hole with a whistle. The cap keeps it from replacing digging; it rewards returning, not idling.

## Residents: the ruins

Kaden's idea: the "enemies" come to live in the town. The hill comes with four wrecked structures you cannot build on or clear. Each underground character has a three-beat arc that ends with you restoring one of the ruins for them; then they live in Hillville, contribute to the loop, and never trouble you again. The whole arc is told in picture speech bubbles. No words.

**The three beats**

1. **Encounter.** Underground, the character does their thing a few times: the Mole steals your shovel, the Caveman waves from the ice, the Foreman's crew is found walled in.
2. **Arrival.** You ride the elevator up and they are waiting at the shaft, hat in hands. Speech bubble: what they did, a sad face; then their ruin, a hopeful face. They want a home and promise to do better.
3. **Fix-up.** Open the build book on the ruin: it shows a restore cost in blocks. Pay it and the ruin rebuilds plank by plank with the unfold animation. They move in, a light comes on, and from then on they help.

| Ruin | Resident | Encounter underground | Restored into | What they give back |
| --- | --- | --- | --- | --- |
| **Old Shed** (collapsed, by the gate) | The Mole | Steals your shovel, pops up elsewhere, apologises; 3 times, then he comes up | **Lost & Found** | Tiles near a buried treasure glow faintly when he is nearby. Every so often a "found" item (a block bundle, a small treasure) appears at the shed door. He still visits underground, now bringing things instead of taking them |
| **Crooked Watchtower** (leaning, mid-hill) | The Gnome Foreman | His crew is found walled into the Gnome Room in the Stone layer | **Gnome Village**, grown around the tower | The overnight dig crew, as planned; the tower is where the Foreman stands with his clipboard and blows the shift whistle |
| **Flooded Cabin** (half underwater, by the pond) | The Caveman | Thawed in the Ice layer, waves, follows you to the elevator | **The Museum** | Displays every treasure found and shows how many are left per layer. He polishes them. This replaces the Museum as a buildable: it is earned, not bought |
| **Ruined Keep** (on the peak, visible from everywhere) | The Dragon | Asleep at the bottom; the soft goal | **Dragon Perch** | As planned: she warms the Ice layer and the town has a dragon. The keep waits visibly for her the whole game, so the reveal lands harder |

- Ruins show their future resident as a faint silhouette on the door once that character has been encountered, so he knows who is coming.
- Restoring is always optional and never times out; the resident waits by the shaft (and keeps being funny) until you do.
- Residents wander the town, react to buildings placed near them, and have idle gags. The Mole falls in the pond. The Caveman is baffled by the Dump Truck. The Foreman inspects barns.
- This is where Hillville gets its cast. A hundred barns is a lot of barns; four residents with stories make it a town.
- Each resident's bible in `openjar-characters` gets a "redemption arc" section so other games can reuse the beat: a character who starts as a nuisance and becomes a friend.

## Vehicles are the progression

Five construction vehicles. Each works both up top and underground, so every unlock is exciting twice. Vehicles are unlocked by building Garages (each Garage opens the next), which keeps the loop honest: dig for blocks, build the Garage, get the Excavator, dig faster. There is no gear, no shop, no stats to read. The vehicle you are driving *is* your level.

| Order | Vehicle | Unlock | Up top | Underground | Toy value |
| --- | --- | --- | --- | --- | --- |
| 0 | **Front Loader** | comes with the hill | Clears 1-tile scrub, carries one building ghost | Scoops 1 tile at a time, slow but fun | Horn, bucket tilt, drives over anything |
| 1 | **Excavator** | Garage 1 (needs the Buried Car) | Clears a 3x2 area, digs ponds | Digs 3-wide, arm reaches up and down | Arm waves, cab spins all the way round |
| 2 | **Dump Truck** | Garage 2 | Hauls a whole shaft pile at once; tipping it out is the best animation in the game | Carries 5x backpack; tips blocks into the elevator | Beep when reversing. He will reverse everywhere |
| 3 | **Crane** | Garage 3 | Places tall buildings (Lighthouse, Water Tower); lifts and moves placed buildings | Lowers you down a shaft fast; hauls boulders out | Swinging hook, ball to knock stumps |
| 4 | **Drill Rig** | Garage 4 (needs the Giant Tooth) | Nothing: it is too big; it parks by the shaft as a landmark | Digs 5-wide straight down on its own while you ride it; the fastest way to the bottom | Spins up with a whine, shakes the screen |

- Vehicles are `.tres` data: dig shape, speed, carry, clear area, sounds, unlock requirement. The Content lane can add a Bulldozer or a Cement Mixer later without code.
- Hop in and out with one button when standing next to one. On foot you have a shovel and a backpack; on foot is always an option so nobody is ever stuck.
- Both players can drive different vehicles at once. The Mole occasionally sits in an empty one and honks.
- **v1.1 vehicle pack (Kaden's wish list, data-only additions after release):** Bulldozer (clears a wide swath up top, pushes loose blocks into piles underground), Cement Mixer (pours a flat foundation that lets buildings go on uneven ground), Steamroller (flattens cleared land into a road tile that vehicles drive faster on), Paver (lays the road tile in a line behind it), Tunneler (digs sideways 3-tall through anything, the horizontal partner to the Drill Rig). Each is a `VehicleData` resource plus sprites; unlock via Garages 5 to 9. Roads are the one new system they imply, so the Steamroller and Paver ship together.

## Camera and controls

**Dynamic split screen.** One camera when both players are in the same scene and within a screen of each other; a vertical split (green left, red right) the moment they are not, including when one is up top and one is underground. The split slides in and out on its own with a soft whoosh; no one manages it. Kaden's rule, verbatim: if both are visible on one screen, the split disappears.

| Situation | Screen |
| --- | --- |
| Both up top, close | One camera framing both |
| Both up top, far apart | Split |
| Both underground, close | One camera |
| Both underground, far apart | Split |
| One up, one down | Split, each half its own scene |
| Solo | Full screen, always |

**The mine shaft transition.** Step or drive into the shaft, the elevator cage closes, a half-second drop with a rattle, cut to underground at your deepest-visited layer (or pick a layer on the way down by pressing up/down, shown as pictures). Coming up is the same in reverse and dumps your backpack at the shaft pile automatically. The transition is the only moment of non-play and it is under a second.

**Controls**

| Input | On foot | In a vehicle |
| --- | --- | --- |
| Left stick | Walk, aim dig direction | Drive; up/down aims the arm or bucket |
| A (Action) | Dig / scoop in the aimed direction (hold to keep digging) | Dig / scoop / tip |
| B (Jump) | Jump; also hop in or out of a vehicle when next to one | Hop out |
| X | Open the build book (up top) | Same |
| Y | Horn. Always. Does nothing. Essential | Horn |
| Start | Pause | Pause |

- Digging is directional and forgiving: hold toward dirt and the tool chews through it. No precision required.
- Placing a building: ghost follows you, A drops it, it snaps. If the plot is not clear, the ghost shows red and the Loader honks; clearing it is one scoop away.
- Underground camera follows the player with a little lead in the dig direction and a slight zoom-out on bigger vehicles.

## Art direction

Chunky 2D pixel art, 16 px tiles, the same tile scale and pipeline Life of a Worm will inherit. Palette from three Hermes proposals; constraint: every underground layer gets a dominant hue so depth reads instantly, and Hillville is warm and sunny against it.

- **Technique:** 16 px tiles, characters 32 px tall, vehicles 48 to 96 px, buildings as multi-tile sprites with a 3-frame "unfold" animation. Nearest-neighbour, whole-pixel camera zoom. Day/night cycle up top as a palette shift (cosmetic; lights come on).
- **Reference feel:** Terraria and Forager for tiles, Stardew Valley for the town warmth, Mini Motorways for snapping satisfaction. Vibe only; original designs.
- **Characters:** Jeff and Chuck in hard hats, pixel renders contributed back to the library. The Mole, Gnome Foreman and Dragon are designed in the library first (bibles, look sheets), then rendered here.
- **Vehicles:** big, round, friendly, with faces in the headlights. Each has a two-frame idle wobble and exhaust puffs. Primary colours plus the player's green or red stripe when a player is driving.
- **Blocks:** each block type is a distinct colour and texture that reads at 16 px: dirt brown, clay orange, stone grey-blue, ice pale blue, crystal purple with sparkle. Treasures sparkle through the dirt from two tiles away.
- **Juice:** dig particles in the block colour, screen shake on big scoops and falls, dust when a building lands, a sparkle burst and a ding when a treasure appears, cows.
- **Store art:** grid is the Excavator mid-scoop with a fossil flying out while Chuck drives and Jeff cheers; hero is Hillville at dusk with the Dragon curled on the peak.

## Audio

Digging and driving are tactile, so the sound carries most of the feel. Soundbox for SFX, Chatterbox for the five characters, ElevenLabs for music.

| Cue | Plays when | Feel |
| --- | --- | --- |
| `dig_<block>` | a tile is removed, by block type | crumble, squelch, crack, crunch, chime |
| `scoop`, `tip` | vehicle bucket and dump | hydraulic whine, rattle of blocks |
| `engine_<vehicle>` | driving, looped, pitched by speed | distinct per vehicle |
| `horn_<vehicle>` | Y | distinct per vehicle; the Dump Truck's reverse beep |
| `treasure` | a treasure appears | sparkle and a ding; bigger for rarer |
| `fall`, `bonk` | loose thing lands, boulder hits you | thud; cartoon bonk with stars |
| `flood` | water pocket opens | gurgle, giggle as you float |
| `elevator` | shaft transition | cage clang, rattle, ding |
| `build_place` | building snaps | clunk, unfold creak, little fanfare |
| `build_move` | picking a building up | pop |
| `tree_fall`, `rock_crack` | clearing land | creak and thump; crack |
| `gnome_whistle` | crew reports or shift change | tiny whistle, marching feet |
| `dragon_snore` | underground, louder by depth | low rumble, shakes the screen at the bottom |

- Music: two linked themes. Up top is a sunny small-town tune (banjo, whistle); underground is the same melody slowed and echoed, gaining a layer per depth zone (the layered-music system Spaceballs built). The Dragon's cavern adds a low choir.
- Barks: the Mole's "oh dear" family, the Gnome Foreman's whistle and clipboard mutters, the Dragon's rumbles and yawns. Jeff names rocks; Chuck narrates his driving.

## Technical plan

Godot 4.7.2 from `openjar-template`, 2D, two scenes (`hillville.tscn`, `underground.tscn`) that can run at once inside two `SubViewport`s for the dynamic split. The underground is a chunked `TileMapLayer` world with edit-only saves and falling debris: the exact engine Life of a Worm needs, built here first and moved into `openjar-addons` once it is proven.

**Underground engine (the Worm head start)**

- World = a seeded procedural grid (200 x 300 tiles) plus a dictionary of edits. Only edits are saved. Chunks of 32 x 32 tiles are instantiated as `TileMapLayer` nodes in a 3 x 3 neighbourhood around each player and freed when they leave.
- Digging: remove tiles in the tool's shape, record edits, spawn particles, add blocks to the shared inventory. Treasures and props are `Node2D`s placed by the seed at fixed layers, with a "discovered" flag in the save.
- Falling: any loose body (boulder, treasure, prop chunk, the Mole) is a `RigidBody2D` that sleeps on solid tiles and wakes when the tile below is removed. Multi-tile props break into chunk bodies when undercut.
- Water pockets: a simple cellular fill that spreads into opened tiles and applies buoyancy to players. Drains over time, faster with Water Towers.
- Lighting: a per-layer darkness overlay and a headlamp `PointLight2D`; Lighthouses lower the overlay for their layer.
- Packaging target: `addons/openjar/tileworld/` (chunk manager, edit store, falling bodies, fill) after v0.1.0, tagged, so Worm imports it instead of rewriting it. Worm swaps the rectangular grid for its polar disk by changing the chunk key and gravity direction only.

**Hillville**

- A side-view `TileMapLayer` surface (scrub tiles cleared by vehicles) plus a ground grid for plots. Buildings are `PackedScene`s with a footprint; placement validates the footprint is clear and snaps to the grid.
- Build book is a `GridContainer` of `BuildingData` cards; cost drawn as block icons from the shared inventory.
- Gnome crew: on load, compute elapsed real time since last save, award `min(cap, rate * hours)` blocks and play the march clip.
  - Ruins: four entries in `data/yard_layout.tres` flagged `ruin`, each bound to a resident id and a restore cost. Unclearable, unbuildable, and the build book shows a restore card for them once their resident has arrived.
  - Residents: a `ResidentState` per character (`unmet`, `encountered` with a counter, `arrived`, `restored`) in the save, driven by `Story.gd`. The Mole advances to `arrived` after 3 thefts; the Caveman on thaw; the Foreman when the Gnome Room is opened; the Dragon on wake. `arrived` spawns them at the shaft on the next elevator ride up.
  - Pictogram speech bubbles: a `PictoBubble` scene (icon sequence with faces, no text) used for the residents' arcs, the build book costs, and goal-style prompts. Built here, then moved to `openjar-addons/ui/` because Junk Yard Zap's goal cards and Spaceballs' upgrade cards want the same component.

**Dynamic split**

- Two `SubViewport`s with their own `Camera2D`, each able to show either scene. A `ScreenDirector` autoload decides per frame: same scene and both within one screen = single viewport full-width; otherwise two half-width viewports, player-coloured divider, tweened in over 0.3 s. Both scenes stay loaded and ticking so the other player's world never pauses.
- This is reusable: it goes into `openjar-addons/ui/split_screen/` for any later game.

**Data (Content lane)**

- `data/blocks/*.tres`: type, colour, dig sound, depth range, value.
- `data/layers.tres`: depth bands, block mix, hazards, light level, dragon snore volume.
- `data/treasures/*.tres`: sprite, layer, unlock, museum text (for Hermes only).
- `data/buildings/*.tres` as `BuildingData`: footprint, cost by block type, unlock requirement, effect, scene.
- `data/vehicles/*.tres` as `VehicleData`: dig shape, clear area, speed, carry, sounds, unlock requirement.
- `data/BALANCE.md`: a first trip to the Buried Car in 5 minutes; Excavator by minute 15; bottom in 3 to 4 hours of total play across sessions.

**Game-specific contracts (add to `docs/contracts.md`)**

```gdscript
signal tile_dug(cell: Vector2i, block: StringName, player: int)
signal treasure_found(id: StringName, player: int)
signal inventory_changed(block: StringName, count: int)
signal building_placed(id: StringName, cell: Vector2i)
signal building_moved(id: StringName, from: Vector2i, to: Vector2i)
signal vehicle_unlocked(id: StringName)
signal entered_scene(player: int, scene: StringName)   # "hillville" | "underground"
signal split_changed(is_split: bool)
signal resident_encountered(id: StringName, count: int)
signal resident_arrived(id: StringName)
signal ruin_restored(id: StringName, resident: StringName)
signal dragon_woken()
func Inventory.can_afford(cost: Dictionary) -> bool
func World.dig(cell: Vector2i, shape: Array[Vector2i], player: int) -> void
```

**Save:** edits dictionary, discovered treasures, inventory, placed buildings (id, cell), unlocked vehicles, each player's deepest layer and last scene, gnome crew timestamp, and a `ResidentState` per resident (replaces the earlier dragon-state flag). Autosave on every elevator ride and every 60 s.

**Performance:** 9 chunks per player of 1,024 tiles is trivial. Watch the number of awake `RigidBody2D`s (cap 60) and particles. Two scenes ticking at once is the only real cost; both are 2D and light.

**Lanes active:** Systems, Gameplay, Art, Content, Audio, Reviewer. All six.

## Premium model budget

Kaden has about $50 of premium-model usage (Fable 5.2, per Kaden; the maker profile confirms the exact model ID before the first session) for this game. Spend it on decisions that every later cheap session inherits: architecture, contracts, art direction, character design. Bulk content, asset generation and routine lane work stay on the default model.

| Slice | Share | What | Why premium |
| --- | --- | --- | --- |
| 1. Art direction | 20% | Three palette proposals, each with mock tiles for every layer and a mock Hillville strip; this game's prompt pack; pixel scale and outline notes | Taste, one shot; every sprite is downstream |
| 2. Character design | 15% | Bibles, look sheets and redemption arcs for the Mole, Gnome Foreman, Caveman and Dragon; Jeff and Chuck hard-hat variants | Permanent library assets across every game |
| 3. Underground engine | 30% | Chunk manager, edit-only save store, falling-body wake logic, water fill, the `TileWorld` API; written as the Phase 1 risk prototype | Life of a Worm inherits it; a clean design pays twice |
| 4. Dynamic split director | 15% | Two-SubViewport design, join/split rules, tween, packaging for `openjar-addons` | Reusable everywhere; cheap models fight Godot viewports |
| 5. Contracts and schemas | 10% | `docs/contracts.md`; `BuildingData`, `VehicleData`, `TreasureData`, `LayerData`; the restore-cost and gnome-crew rules | Every lane codes against these |
| 6. Reserve | 10% | One architecture review after the grey-box; the single nastiest bug of the build | Never spend to zero |

- Slices 1, 2 and 5 are the design sprint (Phase 0). Slices 3 and 4 are the Phase 1 risk prototypes. The premium budget is spent in the first week, on the foundation.
- **Runs now, in parallel (decided 2026-11-09).** The Hill's Phase 0 and Phase 1 start immediately on the premium model, overnight, while the default-model lanes build Junk Yard Zap. The tile engine and split director are proven weeks early, and the four new character bibles land in the library before any other game needs them. Build order for the full game is unchanged; only the foundation moves up.
- Wiring: the Systems lane doc (Phase 1 only) and the Art lane doc (palette and characters only) carry a `model:` line naming the premium model. The maker profile logs spend per slice in `GAME.md` and switches a slice to the default model when its share is used, with the premium output as the spec.
- Not premium: all Phase 3 lane work, every `.tres` content row, Reviewer passes, playtest transcription, polish, CI.

## Build phases

| Phase | Lanes | Output | Tag |
| --- | --- | --- | --- |
| 0. Design sprint | Hermes + Kaden | This doc becomes `GAME.md`; palette picked; Mole, Gnome Foreman and Dragon bibles approved; repo `the-hill` created from the template (public, topic `openjar-game`, `dev` branch) |  |
| 1. Risk prototypes | Systems, solo | (a) Chunked diggable grid with edit-only saves and falling boulders at 60 fps; (b) two SubViewports showing two scenes with the split tweening in and out | `v0.0.1-dev.1` |
| 2. Grey-box | Systems, solo | Two capsule players, Front Loader as a box, dig one tile, elevator between a flat Hillville and the top layer, one placeable barn box, every action beeps | `v0.0.2-dev.N` |
| 3. Parallel build | all lanes | Gameplay: layers, treasures, hazards, build book, vehicles, gnome crew, dragon reveal. Art: tiles, characters, vehicles, buildings, Hillville. Content: blocks, layers, treasures, buildings, vehicles, balance. Audio: full cue sheet, two themes, barks. Systems: split director, inventory, save, HUD | `v0.x-dev.N` |
| 4. First playable | Hermes promotes | Dig to the Clay layer, find the car, build a Garage, drive the Excavator, with placeholder art; **Kaden and his son play it** | `v0.1.0` |
| 5. Extract the engine | Systems | Move the tile world and split screen into `openjar-addons`, tagged, so Life of a Worm can start | addons `v0.2.0` |
| 6. Polish | all lanes | Final pixel art, all five vehicles, all buildings, the Dragon, music, store art, tuning from playtests | `v0.x` |
| 7. Release | Hermes | On the TV main tile | `v1.0.0` |

**First playable definition:** two players dig from the surface to the Clay layer, find the Buried Car, bring blocks up, build a Barn and a Garage, drive the Excavator, with the split screen working when one is up and one is down; saves survive a quit; every action has a sound and a visual. Art may be coloured squares with faces.

## Kid-design checks specific to this game

On top of the template checklist in `docs/kid-design.md`.

- [ ] Nothing underground can hurt the player. Floods float, boulders bonk, cave-ins get you dug out by the Mole.
- [ ] The game never refuses a building choice. A hundred barns is allowed and celebrated.
- [ ] Buildings move for free; nothing placed is a mistake.
- [ ] The backpack never hard-stops digging; a full backpack is a happy icon, not a wall.
- [ ] The split screen appears and disappears on its own; there is no split button.
- [ ] The shaft transition is under one second and skippable.
- [ ] Costs are shown as block pictures, never numbers.
- [ ] On foot is always available; a player can never be stuck without a vehicle.
- [ ] Depth is shown as a picture strip of layers, not metres.
- [ ] The Dragon is sleepy and friendly from the first frame; the reveal is a surprise, not a scare.
- [ ] The gnome crew rewards coming back, with a cap, and never makes digging pointless.
- [ ] A resident's arrival is funny-sad, never sad: the Mole holds the shovel like a bouquet, the Caveman is thrilled to be anywhere. No crying, no begging.
- [ ] Residents never block anything: restoring a ruin is always optional, never required to progress, and the resident keeps being funny while they wait.

## Out of scope and open questions

**Out of scope for v1**

- Shops and buildings you walk inside. Cut, not deferred: vehicles are the progression and they are better at it.
- Gear or stats of any kind.
- Individual block placement. Buildings are prefabs.
- Enemies. The Mole, boulders and floods are the whole "threat" list.
- A second hill. Natural later update.

**Open questions for Kaden**

- [ ] Palette: pick one of three.
- [ ] Approve or edit the Mole, Gnome Foreman, Caveman and Dragon bibles, each with its redemption arc (Hermes drafts them in `openjar-characters`).
- [ ] Real places: no. Landmarks are generic (a water tower, a shop, a house), nothing tied to any real place. Decided 2026-11-09.
- [ ] The hill keeps going below the Dragon: a strange, unbreakable set of layers sits at the very bottom in v1, for a later update. Left and right edges are a plain, obviously-the-edge bedrock block, also unbreakable in v1, removable later to expand outward. Decided 2026-11-09; see World borders.
- [ ] Vehicle wish list from Kaden: Bulldozer, Cement Mixer, Steamroller, Paver, Tunneler. Queued as the v1.1 vehicle pack; see Vehicles. Decided 2026-11-09.


## Playtest 2026-11-10 changes (Kaden; these supersede the sections above)

Full notes, quoted: `playtests/2026-11-10.md`. Lanes follow this section where it differs from anything above.

1. **Story intro.** The game opens on a short intro scene: Jeff and Chuck have inherited the hill ("ours to do as we want with it"), with a warning to be careful of the mineshaft ("There's crazy stuff that happens down there"). Someone explains it (Kaden: "I think we have some sort of intro scene where somebody explains that to us"). Gary's pick: **Mayor Pip** hands over the deed and warns about the shaft; **Foreman Dot** shows them the Front Loader and that clearing the land is its job. Voiced lines plus picture bubbles, skippable with A, played once per save (replayable from the pause menu).
2. **Cutscenes for every major NPC moment** (Kaden: "with the major or important NPC interactions, let's do some kind of cutscenes so that it is obvious what's happening"). A reusable cutscene player: input locked, letterbox bars, the camera moves to the moment, characters act it out, voiced lines and picture bubbles, A skips. Used for the intro, each resident's encounter, arrival and move-in, the Dragon reveal, and each vehicle unlock.
3. **The Mole's arc rebuilt** (supersedes "steals your shovel, pops up elsewhere, apologises; 3 times"): he does not show himself at first. Hints come first (a wobbling tile, a dirt trail, a shovel-shaped shadow). Then a cutscene: he sneaks in, you see him, he steals your shovel. With no shovel you can't dig; the screen fades and you wake up top by the shaft, and the Mole hands the shovel back (sheepish). Spaced out over play, not back to back. After the third time he comes up for good (arrival beat as before).
4. **Digging is much slower at the start, and depth is gated** (supersedes "dig down in big satisfying chunks" for on-foot digging). Each layer is an unlock zone: you can't dig straight to the bottom from the start. Each deeper layer needs something you earn (a shovel upgrade from the Workshop, a vehicle, a treasure), shown by a visible, readable boundary. Digging gets faster and more fun as you progress (better shovels, vehicles), and the deeper layers give real reasons to take vehicles down the shaft (blocks only a vehicle can break, big hauls, vehicle-only treasures).
5. **No tearing down the environment by hand** (supersedes "on foot you have a shovel" for the surface): trees, stumps, rocks and scrub up top can only be cleared with the Front Loader (and later vehicles). That gives the Front Loader something to do right away. Underground digging on foot stays.
6. **Turning and aim.** The character and the dig target must line up: no teleport or jitter when turning, the character never jumps to either side of a pointer, and a clear marker shows exactly which tile you'll dig next, attached to the character.
7. **Getting back up out of the mine** (Kaden: "Let's get creative on how we can go back up when we need to"). Gary's picks: (a) dig toward a tile above you and the shovel carves a step and you climb it, so you can always dig your way up; (b) the elevator can be called from any layer you've reached, with its rope hanging down the shaft; (c) the Gnome crew later adds ladders. Test it in play: from any spot you can get back to the shaft in under about 20 s.
8. **Context control hints on screen.** A small hint panel shows the buttons that matter right now and changes with the situation: on foot B = jump, next to a vehicle B = get in, in a vehicle B = get out, A = dig / scoop, and so on. Controller glyphs, big and clear.
9. **The mineshaft elevator reworked.** A new button to ride it (Gary's pick: **A** on the elevator, not walking into it). Standing on it shows the button above your character, blinking when it's ready to go down or up. A second player within a set radius gets pulled along for the ride.

## Decisions made without Kaden

- 2026-11-10 (Gary, from the foundation director's questions): water stays conserved (keeps "drain or redirect water" honest) but pockets are big and **gush for a couple of seconds** when breached, so a tunnel floods and floats you up, as the plan wants. The **elevator door waits about 1 s** so both players can hop in and ride together. Camera zoom (now 2.0, a player is ~56 px on a 1080p TV) gets checked on the TV/desktop at the first playtest; likely 3.0.
- 2026-11-10 (Systems lane, Showtime menu adoption, D48 d): the menus use the template's Showtime kit with The Hill's skin in `data/menu_skin.tres` (the path the kit reads; `data/README.md` notes the UI lane owns that one file). Palette A colours: accent gold `#ffd23f`, sunburst sky `#58c4f0`, deep topsoil `#3e2a21`. The title is a pixel logo (`assets/ui/the_hill_logo.png`, drawn by `art/tools/make_logo.py`) and keeps the kit's slight tilt. The card under the wipe says "DIG IN!" instead of "ROUND 1" (The Hill is a sandbox, it has no rounds). Jeff and Chuck stand on the podiums at **8x** (a whole number: 4x the in-game zoom of 2, which fills the podium; the in-game size is unchanged). The backdrop is a live Hillville framed on the head-frame, with the saved scrub and the **saved time of day** (main.gd restores the clock at boot; `--time=` still freezes it); placed buildings are not drawn there (BuildController is gameplay), which the blur hides. Solo is never restored from settings at boot. The pause menu's way back to the launcher is the "Back to Open Jar" bar; dev had no separate icon, so none was added.
- 2026-11-10 (Systems lane, character chooser adoption): The Hill plays whoever was picked in the lobby chooser (Roster, synced from openjar-characters v0.3.0: Jeff, Chuck; residents are never choosable). Jeff and Chuck stay the P1 / P2 defaults with their hand-made side-view sheets; any other roster character gets a sheet built at runtime from its front-view pixel form (walk, dig, jump, ride in the cab, sleep in the bucket, with a shovel), so new characters play the night they are synced. Slot colour stays P1 green / P2 red whoever is picked; the podium plates name the pick. No character has voice barks yet: a swap plays the generic `char_swap` cue.
- 2026-11-10 (Gameplay lane, residents and hazards):
  - **Layer darkness** (`LayerData.darkness`, checked in real frames with headlamps): Topsoil **0.3**, Clay **0.6** (the art lane's first try; the headlamp pool now reads around a player in both), Stone 0.8, Ice 0.5, Crystal **0.15** and the Bottom **0.3** kept. Crystal is "self-lit" in the plan, so the headlamp is meant not to matter there; the Bottom reads warm and moody with the Dragon's light. Recheck on the TV.
  - **Hazards never take anything** and never stop play for long: a boulder bonk is a 0.7 s stun with stars (input reads idle, gravity still works) and the boulder bounces off sideways; a cave-in fills the air around the digger with the layer's block and the Mole digs them out about 1.6 s later, and the game frees them itself at 4 s whatever happens. Each cave-in zone drops once per visit underground. A player can also dig themselves out.
  - **Hazard counts are data** (`data/hazards/`, a new `HazardData` row type the Content lane should adopt): the first ten minutes (Topsoil, Clay) have 2 Topsoil boulders, 3 Topsoil cave-ins, 4 Clay boulders, the big Clay pocket plus 2 small ones, and 3 Clay cave-ins, with one of each kind near the landing. The first-playable layout (big pocket, Clay and Stone boulders, the Buried Car) did not move.
  - **The Mole is "he"** (his bible), although the task brief said "she". His rescue does not count as a shovel-theft encounter, so his arc is untouched.
  - **The Gnome Foreman and a crew of three stand right of the shaft pile from the start** (the crew uses the Foreman's sprite, smaller and tinted, until a crew sheet exists). A delivery of 3 or more blocks at once (a ride's dump, not a single scoop) makes them cheer; the Foreman whistles and holds up a picture of the build book. On every new building they march past it and back. They still stand at the Gnome Room underground and whistle when a player arrives there.
  - **The Caveman thaws by headlamp only** for now: stand beside his ice block for 3 s (warmth is never lost by walking away). Digging the block free and carrying it up is left for later. Once thawed he walks to the shaft and is up top waiting by a small campfire right of the crew (his ARRIVED beat, "waiting at the shaft"), saved.
  - **The Dragon's first meeting** plays when a player comes within about 19 tiles of her in the cavern: a stir, a big yawn, three smoke rings, a purr, back to sleep (about 4.6 s, never fire, no screen shake). It plays once per save; she becomes ENCOUNTERED, not ARRIVED, so the Ruined Keep is not offered yet. `Events.dragon_woken` is kept for the full arc.
  - **`--demo-beat=<bonk|float|rescue|cheer|thaw|reveal|crystal>`** (with `--demo`) shows one moment each; it sets the stage directly (places the players, carves a little room, fills the backpack for "cheer", adds the Barn for the march) and then the real systems play it out. The full `--demo` is unchanged.
- 2026-11-10 (Gameplay lane, vehicles and treasures):
  - **The ladder past the first Garage follows Vehicles:** Garage 2 gives the **Dump Truck**, Garage 3 the **Crane**, Garage 4 the **Drill Rig** (needs the Giant Tooth). **Each Garage stores its vehicle:** after a reload, vehicle N parks in front of Garage N's door (else by the shaft). The Drill Rig always parks by the shaft as a landmark.
  - **A Garage built before its vehicle's treasure is never refused:** it goes up, its door stays shut (`garage_waits`), and it rolls up by itself the moment the treasure is found, and the vehicle rolls out. The Garage card shows a picture bubble of the vehicle it gives next, plus (ringed in gold) the treasure that vehicle still waits for as a dark silhouette.
  - **Dump Truck** (blue, fastest at 150 px/s, carries 5 backpacks): up top, A with a load tips the whole bed out at once, wherever the truck is; the blocks go to the pile and the crew cheers. Riding the elevator up tips the bed too. Pushing the other way reverses with a beep for 1 s before it turns round (he will reverse everywhere).
  - **Crane** (teal): underground, A within about 5 tiles of a boulder drops the hook and hauls the boulder out for good (4 stone into the bag). The haul is saved as `hauled`. Otherwise A digs 3 tall at tier 2. Up top it clears 4x2 and opens the tall buildings (Lighthouse, Water Tower). "Lowers you down a shaft fast" is not done.
  - **Drill Rig** (purple): underground, A starts it drilling 5 wide straight down on its own (about 6 rows a second); A again, hopping out or reaching Strangestone stops it. Steering is ignored while it drills. It gives a gentle camera rumble when Settings allows screen shake. Up top it only spins up and puffs.
  - **The build book shows the Crane's buildings before the Crane:** the Lighthouse and the Water Tower sit greyed at the end with a Crane bubble. Picking one bounces the bubble (`book_hint`), never a honk. The Garage keeps its hidden-until-the-Buried-Car gate, so the car flow is exactly as before.
  - **Treasures per layer** are the plan's Underground table: Topsoil bottle caps (near the landing: the first-minute find), boot, bike; Clay bathtub, fossil (plus the car); Stone dinosaur skeleton (plus the Gnome Room and the tooth); Ice pirate chest (the Caveman stays a resident); Crystal the Dragon Egg. The Bottom's "last treasure" is left to the Dragon's arc. The new ones are **pickups**: found by digging within 2 tiles, they pop up over the finder (sunburst, sparkles, about 2 s), fly into the bag and leave the ground. The car, tooth and Gnome Room stay where they lie, unchanged. Pickups are placed with their own seeded rng after the hazards, so the car, boulders and hazards did not move.
  - **The Treasure Shelf** stands up top right of the Caveman's fire, on plot cells 47-48 (a new no-build zone, `shelf`; the seeded scrub right of it shifted). It has one board per layer. A found treasure stands in colour; one still underground is a dark silhouette, which shows how many are left per layer with no numbers. A new find sparkles until a player walks up, then pops into place (`shelf_place`). When the Flooded Cabin becomes the Museum, the shelf should move inside.
  - **Water Tower** (15 stone, 10 ice, 2x3, needs the Crane): each one drains 2 water cells around every player underground every 0.4 s, from the top down.
  - **`--demo-beat=garage|truck|crane|drill|treasure|book|shelf|lineup`** show Garage 2 rolling out the Dump Truck, a full tip with the reverse beep, a boulder haul, the drill boring down, a bottle-cap reveal followed by the shelf pop, the build book's picture bubbles, a full shelf beside a Water Tower, and all five vehicles in a row.
- 2026-11-10 (Gameplay lane, resident arcs and ruins):
  - **Merged `feature/vehicles-treasures` into this branch** (clean merge) so the Museum could take over the Treasure Shelf; that branch was not in `dev` yet.
  - **Arrival bubbles** play when a player comes within about 3 plots of a waiting resident and replay after every player has walked away (so each ride up reminds him, without nagging). Two pictures each: what they did with a sheepish face (Mole: the shovel; Foreman: a wall with hard hats peeking over; Caveman: an ice cube; Dragon: a shaken hill), then their ruin with a hopeful face. Residents near each other take turns. While waiting, the Mole holds the shovel with three flowers like a bouquet, the Foreman holds his hard hat, the Caveman beams (twinkles) by his fire.
  - **Where they wait:** Mole just left of the shaft, Foreman at the pile (he was there from the start; now his crew joins him only once freed from the Gnome Room), Caveman by his fire, the **Dragon on the peak beside the Ruined Keep** (her bible: she "waits on the peak"); she comes up the shaft in three slices (head, middle, tail) and flies over.
  - **Restore cards** are the build book's first cards while a resident waits (the ruin you stand at comes first, so opening the book "on the ruin" focuses it; others follow). The card shows the building it becomes, at the ruin's cost in blocks. Paying rebuilds it in 10 plank rows (about 1.2 s, a plank sound each) with the unfold bounce, then a cheer and a door light that stays on day and night. Restored buildings are not in `Progress.buildings`: they cannot be picked up, moved or undone. The book code (`scenes/ui/`) is unchanged; BuildController feeds it the cards.
  - **Restored art** (Lost & Found, Gnome Village, Museum, Dragon Perch, each with a night-window layer) is drawn in code by `art/tools/make_restored_art.py` with the same kit as the ruins.
  - **Lost & Found:** a found bundle (a crate with a ribbon) appears at the shed door every 150 s of play while none is waiting (saved); walking up to it gives 5 blocks of the deepest layer anyone has visited. No treasures are given (they gate Garages). The underground side (glow near treasure when he visits) is in the underground notes below.
  - **Gnome Village:** the Foreman moves into the tower (shift whistle every 40 s when someone is near), the crew stays at the pile. On load, `Rules.gnome_award(now - "gnome_stamp")` blocks (none under 30 min, 20 to 50) go on the pile, spread over the layers down to the deepest visited, and five little gnomes march out of the shaft with a block each. The stamp is written on every save. No barn bonus yet.
  - **Museum:** the Treasure Shelf moves onto a little dock right of the Museum, over the pond; full boards get a gold star; the Caveman stands by it and polishes one found treasure every 3 s (a twinkle). The shelf stays by the shaft until then.
  - **Dragon Perch:** she flies up and curls on the nest on top, snoring smoke puffs. `Story.ice_warm()` is true; ice is not slippery anywhere yet, so the gameplay part is only visual until slipping exists.
  - **Town life:** residents within about 6 plots of a new building hop with a picture of it and a heart. Gags only fire where a player can see them: the Mole pops up in the pond by mistake (splash, flail, climbs out, shakes off; every 45 s at most when a player is by the pond); he honks the horn of a parked vehicle nobody is in (every 50 s at most); the Caveman leans in and jumps back with a "?" bubble when the Dump Truck is near (every 15 s at most); the Foreman walks to the nearest barn, holds up a barn-and-star bubble, whistles and walks back (every 30 s, once he is up top).
  - **`--demo-beat=arrive|restore_mole|restore_gnomes|restore_caveman|restore_dragon|town`** (`scripts/gameplay/arc_beats.gd`).
  - **Underground encounters:** the Mole steals the shovel by tiles dug on foot in Topsoil or Clay (after 6, then every 14, at least 20 s apart, never during a rescue, never while driving); he pops up behind the player, takes it, says sorry in pictures and gives it straight back (about 3 s; the player is never stopped). A theft cut short before he grabs it does not count. After the third he dives "up"; from then on he only comes underground for cave-in rescues and, once the Lost & Found stands, to visit: every 25 to 35 s he pops up by a player for 6 s, unfound treasure within 12 tiles glows, and he leaves 3 of that layer's main block on the pile.
  - **The Gnome crew** waits behind a brick wall at the Gnome Room with their hats bobbing; opening the room frees them (wall crumbles, whistles, the Foreman ARRIVES) and they march off toward the nearest player and fade (they do not walk the rock to the shaft).
  - **The Caveman** follows the nearest player after thawing and goes up when that player is at the shaft (within 48 px), when nobody is underground, or after 25 s.
  - **The Dragon's second meeting** (100 px from her, or 2 s within 170 px, not in the 1.5 s after her first yawn) wakes her properly: shaken-hill bubble, keep bubble, a purr (`Events.dragon_woken`), then she leaves up the shaft in three slices. Warm Ice: the Ice band's darkness at 0.55x with a warm tint and drips.
  - **More beats:** `--demo-beat=steal|walled|follow|wake|visit`.
- 2026-11-10 (Story lane, playtest items 1-3):
  - **Cutscene player** (`docs/cutscenes.md`): data-driven scenes in `data/cutscenes/`, letterbox bars, eased camera, picture bubbles, voiced lines, A skips the whole scene (state changes still happen), a 90 s cap so it never softlocks. **Split screen: both halves show it** when both players are in that scene's world; a half on the other scene keeps its own camera under the bars, and both players are held.
  - **Intro** about 41 s: Mayor Pip walks in, hands over the deed (it flies to P1), the players hop and cheer, the camera pans to the shaft (Pip: "crazy stuff happens down there", pictures: shaft, question, sparkles; nothing scary), then Foreman Dot at the Front Loader (it hops and honks; pictures: loader, tree, rock). Plays once per save, a little after the game starts, only when someone is up top; **Story** in the pause menu replays it. A save from before this build sees it once.
  - **The Mole's arc**: he stays out of sight at home while he still steals (he still comes for cave-ins). Hints over the gap: a wobbling tile at 30%, a dirt trail at 55%, a shovel-shaped shadow at 80%; then the theft scene. Gaps (`data/story/mole_arc.json`): first after 75 s underground and 12 tiles on foot in Topsoil/Clay; second and third after 180 s and 30 tiles each, at least 14 and 26 rows below the Topsoil landing. With no shovel the player can walk and swing but digs nothing for 3 s (a shovel-and-question bubble), then fade, wake up top beside the shaft, he hands it back. The encounter counts when he gives it back; the third time he walks to his waiting spot and stays (no second arrival scene).
  - **Other scenes** frame what the residents already do (crew freed, Caveman thaw, Dragon reveal and wake), an arrival scene when someone is up top after a resident comes up, a move-in scene when a ruin finishes rebuilding, and Foreman Dot showing off each vehicle a Garage rolls out. They wait while anyone rides the elevator or the crane. The full `--demo` plays none of them by itself.
  - **Voices**: every spoken line is in `data/story/lines.json` (Pip and Dot speak; the Mole only says his "oh dear" family; the Gnome Foreman, Caveman and Dragon stay wordless, per their voice READMEs). Until Gary's files land, a line plays the speaker's library bark or a sound cue, with the picture bubble.
- 2026-11-10 (Gameplay lane, loose things, W-19 / W-20):
  - **Treasures drop whole when dug out from under** (every treasure but the car, the bathtub and the Gnome Room): the picture, its sparkle and its glow ride along, it lands upright with a small bounce and a sparkle, and stays where it lands, glowing. Digging beside a treasure finds it as before; digging under it makes it loose instead, and a loose pickup is found when a player presses A (a dig or a swing) next to it once it has landed: the usual reveal pops it over them. The tooth (stays) drops and is found as before.
  - **The Buried Car, the bathtub and the Gnome Room crumble into chunks** cut from their own picture (one per footprint tile), with the `wall_crumble` cue and a puff per chunk. Chunks are loot: they fall and bounce but never block a player. **Nothing is lost (the "loose pieces" option):** the car and the Gnome Room are found when they crumble (the Garage, the crew walk out, exactly as a find), and A by a chunk pops it into the backpack as one block of that layer (`pop`; a full backpack puffs and the chunk stays). The bathtub's chunks are the bathtub: A by any of them finds it, all of them go and the reveal shows the whole tub.
  - **The Mole falls when his floor at home is dug out:** he drops (no tile passes through him), bounces once (`fall`, a dust puff), waves at the nearest player (`mole_wave`) and shuffles on from where he landed; a wall turns him round. Going home after a rescue, theft or visit puts him back on his home floor. Never hurt, nothing taken.
  - After a reload, a treasure whose ground was dug away drops (or crumbles) again, so it lands about where it was. A car or Gnome Room that crumbled before the save crumbles again on load and its chunks are back to pick up (a few free blocks, never a loss).
  - **`--demo-beat=drop|crumble|mole_fall`** (`scripts/gameplay/loose_beats.gd`).
- 2026-11-10 (Adjacency lane, C-23 / C-26):
  - **Hearts between buildings that like each other** (`data/adjacency.tres`, `scripts/gameplay/town_adjacency.gd`): two liked buildings with at most `radius_plots` (3) empty plots between them get hearts floating back and forth over their roofs and a little flower bed between them. Restored resident homes and the landmarks `shaft` and `pond` count. Pairs: Barn+House, Barn+Gnome Village, Garage+Workshop, Workshop+shaft, Water Tower+pond, Lighthouse+pond, House+House, House+Lost & Found, Workshop+Museum, Lighthouse+Dragon Perch.
  - **The ghost previews it:** while a ghost sits on a good plot, soft hearts on a dotted trail reach from it to each building it would like; each partner hops and `heart_preview` pings. A red ghost shows none.
  - **The reward** for a new pair (after the unfold): a big heart pops over the arc, gold sparkles at both roofs, both buildings hop, the `town_hearts` chime, and the flowers grow. Once per pair: loading a save shows the pairs already grown, and moving a building away wilts its flowers.
  - **Not built:** GAME.md's invisible adult-layer bonuses (crew hauls more beside barns, faster pond drain, extra lit layer, Mole finds more). Hearts and flowers only.
  - **`--demo-beat=adjacency|pond|heart_row`** (`scripts/gameplay/adjacency_beats.gd`).
- 2026-11-10 (Hazards lane, lava pockets W-14, hill-lava-1):
  - **The lava bounce was already on `dev`** (Hazards-3: pools placed from `data/hazards/crystal_lava_pocket.tres`, 4 per world, a ~66 px hop, no damage). This pass adds only the "that's why": a **1 s flame icon** over the bounced player's head with a short **warm orange flash** on their body, a **small camera kick** (`ScreenKick`, 2.5 px for 0.25 s) on the bounced player's view, and a **flickering** glow over each pool. No text anywhere.
  - **The camera beat is a kick, not a pan to the pool.** The pool is always under the player's feet at that moment, so it is already on screen; a pan would belong to the Camera lane (S-06).
  - **The bounce's own cue is `lava_boing`** (Audio lane). Until that file exists, `dragon_boing` plays, so the action is never silent.
  - **No shovel, still a bounce:** lava never looks at the player's tool.
  - **"Digs into lava"** = digging into a pocket's room and walking or falling onto the pool. Digging out the floor under a pool is still possible (the pool then floats over a hole); left to the Dig lane (`hill-dig-1`), which owns what can be dug.
- 2026-11-11 (Underground engineering lane, C-22 puzzles):
  - **Built on `dev`, not on `feature/hill-puzzles-1` / `-fix-1`.** Those branches (pushed 2026-11-10) never reached `dev`; their heavy block is in Topsoil away from the landing (the review's "about 60 tiles from the shaft"), the Dump Truck can lift it too, their wall breaks when a strut is knocked out rather than when a boulder lands, and they add four palette blocks. This pass is narrower and replaces them; Gary should close those branches rather than merge both (same file names: `scripts/gameplay/puzzles.gd`, `scripts/data/puzzle_data.gd`, `tests/test_puzzles.gd`, `data/puzzles/`).
  - **Puzzles are data rows** (`data/puzzles/*.tres`, `PuzzleData`), placed per seed on their own random stream after everything else, only in a layer whose `LayerData.hazards` lists the kind (`clay.tres` now lists `boulder_wall` and `vehicle_block`). One of each, both near the Clay landing (within `NEAR_X`), so a family meets them in the first session. No earlier placement moved (test).
  - **No new tiles.** The cracked slab, its side posts and the heavy block are the world's edgestone cells, drawn over with placeholder art by `Puzzles` (cracked bricks; a grey block with yellow hazard stripes and bolts). A new palette block would need columns in the Art lane's terrain and icon sheets and `ICON_COL` entries in three other lanes' files. If edgestone ever becomes breakable (`breakable_from_version` 2.0.0, not read at runtime today), these need their own tile.
  - **The boulder wall:** an open room over an 8-wide cracked slab; the boulder sits on a one-row dirt pillar in the middle of the room. Dig the pillar and the boulder drops onto the slab; a body at least 20 px wide landing at 90 px/s or more (a one-row drop is about 177 px/s) breaks the whole slab, with a dust puff, a crash and a 5 px camera kick for everyone within 20 tiles. Under it is a small chamber with a Stone floor (the gift: a layer's block early). The floor was ore at first; ore is a minor kind and `test_minor_blocks` holds that minor kinds come only from the minor layout, so it is Stone. The wall's boulder is spawned by `Puzzles` and appended to `Underground.boulders`, not to `generator.boulder_spots`, so every earlier boulder index (and saved Crane hauls) stays put. A pebble only clinks. The pillar is one row (feet height) so the boulder sits beside the digger's head, not over it: a two-row pillar bonked the digger and the boulder bounced back onto the pillar's stump.
  - **The camera beat is a ScreenKick, not a pan** (the Camera lane owns pans, as with lava).
  - **The Front Loader block:** 2x2, two Loader digs (a wobble and a thunk, then it pops away with a puff, 2 stone into the Loader's bag). Hand, Mole, Excavator and every other vehicle clunk off it. It is the Loader's ordinary dig (`HillPlayer.dig_now` -> `TileWorld.dig` -> `dig_blocked`), which Underground now hands to `Puzzles` first; no new movement.
  - **The vehicle hint is a picture bubble over the block** (`PictoBubble`, the Front Loader's sprite) while a player who is not in the Loader is within 5.5 tiles; a clunk pops it too. The context hint panel (`HillHintLayer`) belongs to the Controls lane and was not changed: `Puzzles.vehicle_hint(player)` returns `&"front_loader"` for them to show.
  - **A Crane can haul the wall's boulder away** (it is an ordinary boulder). Then that wall stays shut for that save. Left as is; the Crane needs Garage 3, and the stone behind the wall is a bonus, not progress.
