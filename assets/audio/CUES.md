# Audio cues

Every file here is made by `assets/audio/tools/make_cues.py` (seeded synth, Python stdlib + ffmpeg)
except the three music tracks. Rebuild: `python3 assets/audio/tools/make_cues.py` (all, ~1 min on 5
cores), or name stems. `--preview handoff/sfx_preview.ogg` stitches the preview.

Loudness: SFX and placeholder barks -16 LUFS integrated (short cues measured looped 10x), minus the trim
column; true peak <= -1 dBTP; nothing above 9.5 kHz. Engine loops -24 LUFS (a bed under the SFX), music
stems -26 LUFS (under the -20 LUFS music). Loops and stems are 22.05 kHz 16-bit PCM `.wav`, imported
uncompressed with loop on, because Vorbis drops ~128 samples at a seam and clicks.

`Audio.play(cue)` rotates `cue_1..cue_N` without an immediate repeat. Design names from GAME.md are
aliases (`Audio.ALIASES`): `engine_<vehicle>` -> `<vehicle>_engine`, `horn_<vehicle>` -> `<vehicle>_horn`,
`gnome_whistle` -> `whistle`, `tip` -> `dump_truck_tip`, `build_move` -> `build_pickup`, `restore_plank` -> `plank`.
Menu cues (`ui_move`, `ui_confirm`, `player_join`, `ui_back`, ...) stay with the Showtime kit's designed synth
(`UiSound`); `Audio.play` falls back to it for those names.

## SFX

| Cue | Files | Plays when | Feel | Trim dB | Cap (gap s, voices) |
| --- | --- | --- | --- | --- | --- |
| dig_dirt | sfx/dig_dirt_1.ogg, sfx/dig_dirt_2.ogg, sfx/dig_dirt_3.ogg | a dirt tile is dug (BlockData.dig_sound) | crumble | -2 | 0.06, 3 |
| dig_clay | sfx/dig_clay_1.ogg, sfx/dig_clay_2.ogg, sfx/dig_clay_3.ogg | a clay tile is dug | squelch | -2 | 0.06, 3 |
| dig_stone | sfx/dig_stone_1.ogg, sfx/dig_stone_2.ogg, sfx/dig_stone_3.ogg | stone, edgestone, strangestone dug | crack | -2 | 0.06, 3 |
| dig_ice | sfx/dig_ice_1.ogg, sfx/dig_ice_2.ogg, sfx/dig_ice_3.ogg | an ice tile is dug | crunch + two tinks | -2 | 0.06, 3 |
| dig_crystal | sfx/dig_crystal_1.ogg, sfx/dig_crystal_2.ogg, sfx/dig_crystal_3.ogg | a crystal tile is dug | D-major glass chime | -2 | 0.06, 3 |
| dig_blocked | sfx/dig_blocked_1.ogg, sfx/dig_blocked_2.ogg | a dig hits an unbreakable tile | springy boing + sparkle | +0 | 0.06, 3 |
| swing | sfx/swing_1.ogg, sfx/swing_2.ogg | a dig that hits nothing | whoosh | -4 | 0.08, 2 |
| mole_dig | sfx/mole_dig_1.ogg, sfx/mole_dig_2.ogg | the Mole tunnels | small scrabble | -4 | 0.2, 1 |
| dig_free | sfx/dig_free.ogg | dug out of a cave-in | crumble | +0 | 0.06, 3 |
| front_loader_engine | sfx/front_loader_engine.wav | driving the Front Loader (loop, pitched by speed) | chuggy little diesel | -8 | 0.05, 3 |
| front_loader_horn | sfx/front_loader_horn.ogg | Y in the Front Loader | beep-beep | +0 | 0.15, 1 |
| excavator_engine | sfx/excavator_engine.wav | driving the Excavator (loop) | deeper, hydraulic whine | -8 | 0.05, 3 |
| excavator_horn | sfx/excavator_horn.ogg | Y in the Excavator | low friendly honk | +0 | 0.15, 1 |
| dump_truck_engine | sfx/dump_truck_engine.wav | driving the Dump Truck (loop) | big low rumble, turbo whistle | -8 | 0.05, 3 |
| dump_truck_horn | sfx/dump_truck_horn.ogg | Y in the Dump Truck | D-major air-horn chord | +0 | 0.15, 1 |
| crane_engine | sfx/crane_engine.wav | driving the Crane (loop) | steady hum, gear ticks | -8 | 0.05, 3 |
| crane_horn | sfx/crane_horn.ogg | Y in the Crane | ding-ding bell | +0 | 0.15, 1 |
| drill_rig_engine | sfx/drill_rig_engine.wav | driving the Drill Rig (loop) | buzzy, whirring bit | -8 | 0.05, 3 |
| drill_rig_horn | sfx/drill_rig_horn.ogg | Y in the Drill Rig | toot-toot whistle | +0 | 0.15, 1 |
| dump_truck_reverse | sfx/dump_truck_reverse.ogg | the Dump Truck backs up | soft A5 reverse beeper x3 | -3 | 0.6, 1 |
| front_loader_dig | sfx/front_loader_dig.ogg | vehicle dig (vehicle.sounds.dig) | hydraulic + clods | -2 | 0.1, 2 |
| excavator_dig | sfx/excavator_dig.ogg | vehicle dig | hydraulic + clods | -2 | 0.1, 2 |
| dump_truck_dig | sfx/dump_truck_dig.ogg | vehicle dig | hydraulic + clods | -2 | 0.1, 2 |
| crane_dig | sfx/crane_dig.ogg | vehicle dig | hydraulic + clods | -2 | 0.1, 2 |
| drill_rig_dig | sfx/drill_rig_dig.ogg | vehicle dig | hydraulic + grit | -2 | 0.1, 2 |
| drill_rig_spin | sfx/drill_rig_spin.ogg | the drill spins | rising whirr | -3 | 0.25, 1 |
| drill_stop | sfx/drill_stop.ogg | the drill stops | winding down | +0 | 0.05, 3 |
| crane_hook | sfx/crane_hook.ogg | the hook grabs | chain rattle, clank | +0 | 0.05, 3 |
| dump_truck_tip | sfx/dump_truck_tip.ogg | the bed tips (design name `tip`) | hydraulic down-whine, rattle of blocks | +0 | 0.05, 3 |
| bucket_tip | sfx/bucket_tip.ogg | a bucket tips onto the pile | whine, rattle | +0 | 0.05, 3 |
| scoop | sfx/scoop_1.ogg, sfx/scoop_2.ogg | a bucket scoops | hydraulic whine, clods | +0 | 0.1, 2 |
| pile_dump | sfx/pile_dump_1.ogg, sfx/pile_dump_2.ogg | blocks land on the shaft pile | rattle | +0 | 0.1, 2 |
| horn | sfx/horn.ogg | generic horn fallback | kazoo honk | +0 | 0.15, 1 |
| honk | sfx/honk.ogg | can't afford it (book stays open) | soft clown bwah | -2 | 0.3, 1 |
| hop_in | sfx/hop_in.ogg | hop into a vehicle | thump, door click, note | +0 | 0.05, 3 |
| hop_out | sfx/hop_out.ogg | hop out | click, thump | +0 | 0.05, 3 |
| vehicle_rollout | sfx/vehicle_rollout.ogg | a new vehicle rolls out of a Garage | hydraulic + arpeggio | +0 | 0.05, 3 |
| garage_door | sfx/garage_door.ogg | a Garage door opens | roller clatter | +0 | 0.05, 3 |
| garage_waits | sfx/garage_waits.ogg | a Garage is waiting for its unlock | hopeful two-note | +0 | 0.05, 3 |
| backpack_full | sfx/backpack_full.ogg | the backpack fills | happy boop-boop | -2 | 1.5, 1 |
| treasure_small | sfx/treasure_small.ogg | a Topsoil treasure is found | two-note ding + 3 sparkles | +0 | 0.1, 2 |
| treasure | sfx/treasure.ogg | a Clay treasure (and the fallback) | three-note ding + sparkles | +0 | 0.1, 2 |
| treasure_big | sfx/treasure_big.ogg | a Stone or Ice treasure | four notes + chord, ducks music | +1 | 0.1, 2 |
| treasure_huge | sfx/treasure_huge.ogg | a Crystal or Bottom treasure | arpeggio + chord + brass, ducks music | +2 | 0.1, 2 |
| treasure_reveal | sfx/treasure_reveal.ogg | a treasure pops out | rising shimmer | +0 | 0.1, 2 |
| treasure_pickup | sfx/treasure_pickup.ogg | it flies to the pile | whoosh + ding | +0 | 0.1, 2 |
| treasure_hint | sfx/treasure_hint.ogg | a treasure is near | faint sparkle | -4 | 0.1, 2 |
| shelf_place | sfx/shelf_place.ogg | a treasure goes on the shelf | wood knock + bell | +0 | 0.05, 3 |
| polish | sfx/polish.ogg | the Caveman polishes a treasure | squeak squeak gleam | -2 | 0.05, 3 |
| fall | sfx/fall_1.ogg, sfx/fall_2.ogg, sfx/fall_3.ogg | a loose thing lands (TileWorld.body_landed) | thud | -1 | 0.08, 3 |
| bonk | sfx/bonk_1.ogg, sfx/bonk_2.ogg | a boulder bonks a player | cartoon bonk with stars | +0 | 0.2, 2 |
| float_up | sfx/float_up.ogg | a player floats up in water | bubbly giggle | +0 | 0.05, 3 |
| flood | sfx/flood.ogg | a water pocket opens | gurgle then giggle of bubbles | +0 | 0.5, 1 |
| splash | sfx/splash_1.ogg, sfx/splash_2.ogg | a player enters water | splash | +0 | 0.15, 2 |
| jump | sfx/jump_1.ogg, sfx/jump_2.ogg | a player jumps | chirp up | -4 | 0.08, 2 |
| shake_off | sfx/shake_off.ogg | a player shakes off water | brr-rr | +0 | 0.05, 3 |
| rumble | sfx/rumble.ogg | a cave-in is coming | distant friendly rumble | -2 | 0.05, 3 |
| cave_in | sfx/cave_in.ogg | a cave-in drops | rumble + thuds | +0 | 0.05, 3 |
| pop | sfx/pop.ogg | something pops free | pop | +0 | 0.05, 3 |
| prop_break | sfx/prop_break.ogg | a buried prop breaks into pieces | crack + debris | +0 | 0.05, 3 |
| wall_crumble | sfx/wall_crumble.ogg | a wall crumbles (arcs: walled crew) | crumble | +0 | 0.05, 3 |
| elevator | sfx/elevator.ogg | the cage rides | clang, rattle, ding | +0 | 0.05, 3 |
| cage_door | sfx/cage_door.ogg | the cage door | slide + clang | +0 | 0.05, 3 |
| elevator_clank | sfx/elevator_clank.ogg | the cage starts | clank | +0 | 0.05, 3 |
| elevator_ding | sfx/elevator_ding.ogg | the cage arrives | ding | +0 | 0.05, 3 |
| build_place | sfx/build_place.ogg | a building snaps down | clunk, creak, little fanfare (ducks) | +1 | 0.05, 3 |
| build_unfold | sfx/build_unfold.ogg | the building unfolds | creaks + knocks | +0 | 0.05, 3 |
| build_pick | sfx/build_pick.ogg | a card is picked in the book | marimba tick | -3 | 0.05, 3 |
| build_pickup | sfx/build_pickup.ogg | a building is picked up (design name `build_move`) | pop | +0 | 0.05, 3 |
| build_cancel | sfx/build_cancel.ogg | placing cancelled | two notes down | -3 | 0.05, 3 |
| cheer | sfx/cheer.ogg | a building is placed | little yay | +0 | 0.05, 3 |
| book_open | sfx/book_open.ogg | build book opens | page + note | -3 | 0.1, 1 |
| book_close | sfx/book_close.ogg | build book closes | page + note | -3 | 0.1, 1 |
| book_hint | sfx/book_hint.ogg | the book points at something | two-note | -3 | 0.1, 1 |
| bundle_pop | sfx/bundle_pop.ogg | a bundle of blocks pops | pop + sparkle | +0 | 0.05, 3 |
| clipboard | sfx/clipboard.ogg | the Foreman writes it down | scribble + clip | -5 | 0.05, 3 |
| tree_fall | sfx/tree_fall.ogg | a tree is cleared | creak and thump | +0 | 0.2, 2 |
| rock_crack | sfx/rock_crack_1.ogg, sfx/rock_crack_2.ogg | a rock is cleared | crack | +0 | 0.08, 2 |
| stump_pop | sfx/stump_pop.ogg | a stump pops | pop + clods | +0 | 0.05, 3 |
| whistle | sfx/whistle_1.ogg, sfx/whistle_2.ogg, sfx/whistle_3.ogg | gnome crew reports / marches (design name `gnome_whistle`) | tiny two-note pea whistle | +0 | 0.12, 2 |
| whistle_muffled | sfx/whistle_muffled.ogg | the walled-in crew | whistle behind rock | +0 | 0.05, 3 |
| march_step | sfx/march_step.ogg | one gnome step | tiny wood tick | -6 | 0.09, 2 |
| crew_march | sfx/crew_march.ogg | the crew marches | tidy little feet | -2 | 0.05, 3 |
| crew_cheer | sfx/crew_cheer.ogg | the crew cheers a delivery | tiny hooray | +0 | 0.05, 3 |
| mole_wave | sfx/mole_wave.ogg | the Mole waves | two notes | +0 | 0.05, 3 |
| mole_steal | sfx/mole_steal.ogg | the Mole pinches the shovel | tiptoe pluck + zip | +0 | 0.05, 3 |
| mole_sorry | sfx/mole_sorry.ogg | the Mole apologises | small 'oh-eh' | +0 | 0.05, 3 |
| mole_hello | sfx/mole_hello.ogg | the Mole says hello | small 'eh-oh' | +0 | 0.05, 3 |
| mole_gift | sfx/mole_gift.ogg | the Mole gives it back | three notes + sparkle | +0 | 0.05, 3 |
| mole_found | sfx/mole_found.ogg | you find the Mole | four notes | +0 | 0.05, 3 |
| mole_pop | sfx/mole_pop.ogg | the Mole pops up | pop | +0 | 0.05, 3 |
| shovel_back | sfx/shovel_back.ogg | the shovel comes back | clink + notes | +0 | 0.05, 3 |
| ice_drip | sfx/ice_drip_1.ogg, sfx/ice_drip_2.ogg | ice drips by the Caveman | drip | -6 | 0.5, 1 |
| ice_crack | sfx/ice_crack.ogg | the Caveman's ice cracks | cracks + sparkle | +0 | 0.05, 3 |
| caveman_laugh | sfx/caveman_laugh.ogg | the Caveman laughs | ho ho ho | +0 | 0.05, 3 |
| caveman_hoot | sfx/caveman_hoot.ogg | the Caveman hoots | oo-OO! | +0 | 0.05, 3 |
| caveman_huh | sfx/caveman_huh.ogg | the Caveman is baffled | huh? | +0 | 0.05, 3 |
| dragon_snore | sfx/dragon_snore_1.ogg, sfx/dragon_snore_2.ogg | underground while she sleeps, louder by depth; gentle camera sway at the Bottom | in-breath and a fluttery purr | -2 | 1.5, 1 |
| dragon_purr | sfx/dragon_purr.ogg | the Dragon purrs | low purr | +0 | 0.05, 3 |
| dragon_yawn | sfx/dragon_yawn.ogg | the Dragon yawns (reveal) | sleepy aaah-mm (ducks) | +0 | 0.05, 3 |
| dragon_flap | sfx/dragon_flap.ogg | her wings flap | soft whumps | +0 | 0.05, 3 |
| dragon_boing | sfx/dragon_boing.ogg | she bounces | low boing | +0 | 0.05, 3 |
| dragon_hopeful | sfx/dragon_hopeful.ogg | she hopes | rising hum | +0 | 0.05, 3 |
| dragon_mumble | sfx/dragon_mumble.ogg | she mumbles | low syllables | +0 | 0.05, 3 |
| dragon_stretch | sfx/dragon_stretch.ogg | she stretches | rising hum | +0 | 0.05, 3 |
| dragon_whoosh | sfx/dragon_whoosh.ogg | she swooshes | whoosh | +0 | 0.05, 3 |
| smoke_ring | sfx/smoke_ring.ogg | she blows a smoke ring | puh + ring | +0 | 0.05, 3 |
| resident_hope | sfx/resident_hope.ogg | picture bubble: hopeful | three notes up | +0 | 0.05, 3 |
| resident_hm | sfx/resident_hm.ogg | picture bubble: thinking | hm | +0 | 0.05, 3 |
| resident_happy | sfx/resident_happy.ogg | picture bubble: happy | three notes | +0 | 0.05, 3 |
| resident_cheer | sfx/resident_cheer.ogg | picture bubble: cheer | yay + sparkle | +0 | 0.05, 3 |
| resident_arrive | sfx/resident_arrive.ogg | a resident waits at the shaft (Events.resident_arrived) | ding-dong + arpeggio (ducks) | +0 | 0.05, 3 |
| ruin_rumble | sfx/ruin_rumble.ogg | a ruin shakes before the restore | rumble | +0 | 0.05, 3 |
| light_on | sfx/light_on.ogg | the restored building's light comes on (Events.ruin_restored) | click + warm chord (ducks) | +0 | 0.05, 3 |
| plank | sfx/plank_1.ogg, sfx/plank_2.ogg, sfx/plank_3.ogg, sfx/plank_4.ogg | each plank of a restore (design name `restore_plank`) | hammer knock, four rising variants | -2 | 0.06, 2 |
| payoff_mole | sfx/payoff_mole.ogg | Mole's arc pays off (0.7 s after light_on) | fanfare + mole hello (ducks) | +1 | 0.05, 3 |
| payoff_caveman | sfx/payoff_caveman.ogg | Caveman's payoff | fanfare + hoot (ducks) | +1 | 0.05, 3 |
| payoff_gnomes | sfx/payoff_gnomes.ogg | the Foreman's payoff | fanfare + whistle + march (ducks) | +1 | 0.05, 3 |
| payoff_dragon | sfx/payoff_dragon.ogg | the Dragon's payoff | fanfare + purr + brass (ducks) | +1 | 0.05, 3 |
| round_start | sfx/round_start.ogg | Game.start_round | three notes + chord | +0 | 0.05, 3 |
| round_end | sfx/round_end.ogg | Game.end_round | four notes down | +0 | 0.05, 3 |
| pause | sfx/pause.ogg | pause / resume | two notes | -2 | 0.05, 3 |
| solo_on | sfx/solo_on.ogg | solo playtest on | two notes up | -2 | 0.05, 3 |
| solo_off | sfx/solo_off.ogg | solo playtest off | two notes down | -2 | 0.05, 3 |
| split | sfx/split.ogg | the screen splits or joins | whoosh | -4 | 0.05, 3 |
| action | sfx/action.ogg | template player action | wood tick | -3 | 0.05, 3 |

Ducks (music pulled down, fast attack, slow release): see `Audio.DUCKS`; every bark ducks -5 dB.

## Barks (placeholders until the voice packs land)

`Audio.bark(character, cue)` plays the character's real line first (`Roster.info(id).voice` dir, else
`assets/characters/<id>/voice/<cue>[_n].ogg`), else these synth gibberish placeholders on the Voice bus.
One bark at a time, 2.5 s between any two, 8 s before the same line again.

| Character / cue | Files | Hook (scripts/audio/hill_audio.gd) |
| --- | --- | --- |
| jeff/rock_name | voice/jeff_rock_name_1.ogg, voice/jeff_rock_name_2.ogg, voice/jeff_rock_name_3.ogg, voice/jeff_rock_name_4.ogg | Jeff digs a rock (stone, clay, ice, crystal...): every new kind, then at most every 30 s |
| chuck/narrate | voice/chuck_narrate_1.ogg, voice/chuck_narrate_2.ogg, voice/chuck_narrate_3.ogg, voice/chuck_narrate_4.ogg | Chuck hops into a vehicle, then every 14 s while driving at over half speed |
| mole/oh_dear | voice/mole_oh_dear_1.ogg, voice/mole_oh_dear_2.ogg, voice/mole_oh_dear_3.ogg | Events.resident_encountered / resident_arrived (mole) |
| gnome_foreman/mutter | voice/gnome_foreman_mutter_1.ogg, voice/gnome_foreman_mutter_2.ogg, voice/gnome_foreman_mutter_3.ogg | 1.2 s after a building is placed (he inspects it); on his arrival |
| gnome_foreman/whistle | voice/gnome_foreman_whistle.ogg | Events.resident_encountered (gnome_foreman) |
| dragon/rumble | voice/dragon_rumble_1.ogg, voice/dragon_rumble_2.ogg | encountered / arrived; 2 s after Events.dragon_woken |
| dragon/yawn | voice/dragon_yawn_1.ogg | voice-pack slot; the reveal plays the `dragon_yawn` SFX |

## Music

| File | Source | Plays when |
| --- | --- | --- |
| music/music_up.ogg | ElevenLabs Music (Gary), 32.6 s loop, -20 LUFS | up top (and in the lobby) |
| music/music_down.ogg | ElevenLabs Music (Gary), 32.6 s loop, -20 LUFS | underground: the same melody slowed and echoed |
| music/music_cavern.ogg | ElevenLabs Music (Gary), 18.6 s loop, -20 LUFS | in the Dragon's cavern, on its own looped player on top |
| music/music_down_layer_1.wav | make_cues.py `stem_drone` | zone 1+ (Clay): warm low D/A drone |
| music/music_down_layer_2.wav | make_cues.py `stem_shimmer` | zone 2+ (Stone): soft high A/D/F# pad |
| music/music_down_layer_3.wav | make_cues.py `stem_bells` | zone 3+ (Ice): sparse echoing bell drops |
| music/music_down_layer_4.wav | make_cues.py `stem_glass` | zone 4+ (Crystal, Bottom): glassy harmonics and air |

The layered system (Spaceballs' idea, built here as `Audio.music_state`): one `AudioStreamSynchronized`
holds up, down and the four layers, all exactly 32.6 s, and each is faded by its stream volume, so
switching never restarts the melody. The stems are D major with no beat (32.6 s is not a whole number
of 80 BPM bars, so anything rhythmic would flam at the seam). Every oscillator runs a whole number of
cycles per loop. The dynamic split: the theme follows where most players are; a tie (one up, one
down) keeps the theme already playing, while the depth layers and the cavern choir follow the
underground player either way. Crossfades take 1.5 s.

## Mix

Buses: Master (hard limiter, -1 dB ceiling) <- Music (duck amplifier) / SFX / Voice (follows the
Sound slider). Engines -7 dB idling to 0 dB flat out, pitch 0.8 to 1.35. 16 SFX voices, the oldest is
stolen; every cue has a rate cap. `--audio-log` prints voice counts every 30 s of game time.
