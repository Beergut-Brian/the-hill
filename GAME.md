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
