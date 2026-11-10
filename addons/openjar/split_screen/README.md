# split_screen: ScreenDirector

Dynamic two-player split screen across any number of 2D scenes. Game-agnostic: no autoloads,
nothing outside this folder. Godot 4.7.

## How it works

```
ScreenDirector (Control, full rect)
├── Hosts (Node)
│   ├── Host_top   SubViewport 2x2, UPDATE_DISABLED, own World2D ──┐  scene "top": own canvas,
│   │   └── <scene root>  └── Players/ (player nodes live here)     │  own physics space; ticks
│   └── Host_mine  SubViewport 2x2, UPDATE_DISABLED, own World2D ─┐ │  whether seen or not
│       └── <scene root>                                         │ │
├── View0 SubViewportContainer (stretch) ── SubViewport ── Camera2D   world_2d = host world of P0
├── View1 SubViewportContainer (stretch) ── SubViewport ── Camera2D   world_2d = host world of P1
└── Divider (Control, 6 px bar, P0 colour | P1 colour, 2 px dark outline, alpha = split_amount)

   split_amount 0             0 < s < 1                 1
  +---------------+     +-----------+---+      +-------+-------+
  |   View0       |     |  View0    |V1 |  ->  | View0 | View1 |
  | (midpoint)    |     |           |   |      |  P0   |  P1   |
  +---------------+     +-----------+---+      +-------+-------+
```

* Hosts own the scenes. They are never rendered, but nodes in them process and their physics space
  steps every physics frame (verified: RigidBody2Ds fall in three hosts at once, including one no
  view shows; no extra setting needed beyond leaving the host in the tree).
* Views only borrow a host's `World2D` (`view.world_2d = host.world_2d`), so they draw that scene's
  canvas through their own Camera2D. Each frame the director picks the worlds, the split, the
  layout and the camera positions.
* The decision is `wants_split()` (pure, static, testable); the slide is a linear phase moved with
  `move_toward` and eased with `smoothstep`, so reversing mid-slide never pops.
* Layout: boundary `x = lerp(W, W/2, s)`; View0 is `[0, x]`, View1 is `[x, W]`. At `s == 0` View1
  is hidden and `UPDATE_DISABLED`. If only player 1 is present the mirror applies (View1 full).
* Cameras: same scene → each target is `lerp(midpoint, own player, s)`; different scenes → each on
  its own player (the one who stayed eases off the last shared midpoint, so its view does not pop);
  solo → on the player. Positions are rounded to whole pixels, smoothing off, `zoom` on both.

## API

```gdscript
var d := ScreenDirector.new()        # no .tscn needed; builds its children on _ready/first use
add_child(d)
d.add_scene(&"top", top_root)        # reparents top_root into its own host
d.add_scene(&"mine", mine_root)
d.add_player(0, jeff, &"top")        # under top_root/Players if it exists, else top_root
d.add_player(1, chuck, &"top")
d.move_player(1, &"mine", Vector2(64, 0))   # elevator: reparent, set global_position, zero velocity,
                                            # emits entered_scene(1, &"mine"), view cuts at once
d.remove_player(1)                   # forgets the player; does not free or reparent the node
d.scene_of(1); d.is_split(); d.camera_of(0); d.view_rect_of(0); d.split_amount
signal split_changed(is_split)       # once per flip, when the slide starts
signal entered_scene(player, scene)
```

Exports: `tween_time` 0.3, `zoom` 2.0, `join_at` 0.6, `split_at` 0.8, `forward_input` true.
`colors` defaults to green `3cc24a`, red `e4393c`.

Optional hook: if a scene root has `func get_camera_limits() -> Rect2`, both cameras showing that
scene get `limit_*` set from it (in world px); otherwise limits are off.

`view_rect_of(p)` is in screen (global canvas) coordinates: the full director rect while joined,
else that player's view rect. Use it to anchor per-player HUD.

## Gotchas

* **HUD goes outside the scenes.** A `CanvasLayer` inside a hosted scene draws to the host's
  canvas layer, which no view shows. Put HUD as a child of the director (added after it builds, so
  it draws above the divider) or anywhere in the normal tree, anchored with `view_rect_of`.
* **No camera inside hosted scenes.** `get_viewport()` there is the 2x2 host: `get_camera_2d()` is
  null, `get_viewport_rect()` is 2x2, `get_global_mouse_position()` is meaningless. Use
  `director.camera_of(player)`. Do not add your own Camera2D to a hosted scene; it does nothing.
* **Input.** Polling (`Input.is_action_pressed` in `_process`/`_physics_process`) works everywhere.
  `_input`/`_unhandled_input` do NOT reach nodes in a plain SubViewport by themselves (verified);
  with `forward_input = true` (default) the director pushes every non-pointer event (keys, pads,
  actions) into each host from its own `_input`, so they do. Mouse/touch events are never forwarded.
  Hosts must keep `gui_disable_input` off, or `push_input` silently drops events.
* **Audio.** Non-positional `AudioStreamPlayer` is unaffected. For `AudioStreamPlayer2D` the visible
  views are 2D audio listeners (`audio_listener_enable_2d` on while shown, hosts off). Not verified
  by test; when split both views listen, so a sound near both players may play twice.
* **Moving players from physics callbacks** (`body_entered` etc.): call
  `move_player.call_deferred(...)`, as removing a body from a space while it flushes queries errors.
* **Pause.** The director inherits `process_mode`; if the tree pauses, the split freezes too.
* Views copy `canvas_item_default_texture_filter` and the 2D snap settings from the director's
  viewport when it enters the tree, so pixel art stays nearest-filtered.

## Demo

`demo/split_demo.tscn`: scripted timeline (together, split by distance, join, split by scene,
back). `scripts/tools/shots.sh res://addons/openjar/split_screen/demo/split_demo.tscn 1,2.6,3.5,7 out`.
`--tween-time=<s>` slows the slide.
