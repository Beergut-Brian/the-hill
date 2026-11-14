## -- --ui=<state>: boots straight into a menu state, frozen, for screenshots (scripts/tools/shots.sh).
## lobby, lobby-joined, lobby-ready, lobby-hold, lobby-settings, lobby-confirm,
## pause, pause-settings, pause-confirm, pause-door (the door icon focused), pause-refuse (right on the door:
## the honk, the door mid-wobble), lobby-refuse (X in the lobby: Play mid-wobble), and the Showtime motion strip lobby-go1..lobby-go6
## (SETTINGS focused, up to PLAY, A: flash + jump, wipe, round card, into the game; each is one
## posed moment, frozen ~1 s after boot), the chooser: lobby-pick (P1 choosing, arrows; P2 ready)
## and lobby-swap (P1's podium posed mid-swap, with the poof). Add --ui-pixel for a pixel_art skin
## (the characters' pixel forms). The lobby calls run() once from _ready().
class_name UiPreview
extends RefCounted

const P1 := Players.P1
const P2 := Players.P2


static func state_from_args(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with("--ui="):
			return a.trim_prefix("--ui=")
	return ""


static func run(lobby: Control) -> void:
	var s := state_from_args(OS.get_cmdline_user_args())
	if s == "" or Game.demo:
		return
	if "--ui-pixel" in OS.get_cmdline_user_args():
		var sk := UiStyle.skin().duplicate() as MenuSkin
		sk.pixel_art = true
		sk.character_scale = 9.0
		UiStyle.use_skin(sk)
	lobby.freeze = true
	if s.begins_with("pause"):
		Players.join_virtual(P1)
		Players.join_virtual(P2)
		lobby.freeze = false
		Game.finish_lobby([P1, P2])
		# Let the game run a moment first: worlds that set up their views while playing (split
		# screen, The Hill's director) are drawn behind the pause blur, as in a real pause.
		await lobby.get_tree().create_timer(1.0).timeout
		Game.pause()
		var pm: Node = lobby.get_tree().get_first_node_in_group("openjar_pause_menu")
		pm.paused_by = P2
		if s == "pause-settings":
			pm.press(pm.Choice.SETTINGS)
			pm.get_node("Settings").move_focus(1)
		elif s == "pause-confirm":
			pm.press(pm.Choice.DOOR)
		elif s == "pause-door" or s == "pause-refuse":
			for i in 4:
				pm.move_focus(1)
			if s == "pause-refuse":
				# Right on the door: no row that way, so the honk and the door rocks. Held mid-rock.
				await lobby.get_tree().create_timer(0.4).timeout
				pm.side_step(1)
				pm.get_node("Card/Door/Icon").pose_wobble(0.92)
		return
	if s.begins_with("lobby-go"):
		_go(lobby, int(s.trim_prefix("lobby-go")))
		return
	if s != "lobby":
		Players.join_virtual(P1)
	match s:
		"lobby-joined", "lobby-settings", "lobby-confirm":
			Players.join_virtual(P2)
			lobby.set_ready(P2, false)
			if s == "lobby-settings":
				lobby.focus_item(lobby.Choice.SETTINGS)
				lobby.press_a(P1)
			elif s == "lobby-confirm":
				lobby.focus_item(lobby.Choice.DOOR)
				lobby.press_a(P1)
		"lobby-ready":
			Players.join_virtual(P2)
			lobby.count_step(lobby.COUNT_STEP + 0.05)
		"lobby-pick", "lobby-swap":
			Players.join_virtual(P2)
			lobby.set_ready(P1, false, true)
			if s == "lobby-swap":
				await lobby.get_tree().create_timer(0.9).timeout
				var spot: Control = lobby.get_node("Spots/P1")
				var slot: CharacterSlot = spot.get_node("Character")
				spot.nudge(1)
				slot.swap_to(Roster.pick(P1))
				await lobby.get_tree().create_timer(0.08).timeout
				lobby.process_mode = Node.PROCESS_MODE_DISABLED
				spot.process_mode = Node.PROCESS_MODE_DISABLED
				slot.pose_swap(0.35)
				for c in spot.get_children():
					if c is Poof:
						c.t = 0.3
		"lobby-refuse":
			# P1 ready, P2 joined; X does nothing here: the honk, Play shakes. Held mid-shake.
			Players.join_virtual(P2)
			lobby.set_ready(P2, false, true)
			await lobby.get_tree().create_timer(0.6).timeout
			lobby.refuse("x")
			lobby.get_node("Buttons/Play").pose_wobble(0.92)
		"lobby-hold":
			lobby.hold_step(P1, true, lobby.HOLD_TO_START * 0.6)


## One frame of the motion strip, posed and frozen. Shoot it at about 1.5 s.
static func _go(lobby: Control, n: int) -> void:
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	if n <= 2:
		lobby.set_ready(P1, false, true)
		lobby.set_ready(P2, false, true)
		lobby.cancel_countdown()
	lobby.focus_item(lobby.Choice.SETTINGS if n <= 2 else lobby.Choice.PLAY)
	var tree := lobby.get_tree()
	await tree.create_timer(0.9).timeout
	match n:
		1:
			return
		2:
			lobby.focus_item(lobby.Choice.PLAY)
			await tree.create_timer(0.09).timeout
			lobby.process_mode = Node.PROCESS_MODE_DISABLED
		_:
			lobby.count_step(lobby.COUNT_STEP * lobby.COUNT_DOTS - ShowtimeWipe.IN_TIME - 0.05)
			await tree.create_timer(0.05).timeout
			var wipe := tree.root.get_node("ShowtimeWipe") as ShowtimeWipe
			if n <= 4:
				lobby.process_mode = Node.PROCESS_MODE_DISABLED
				wipe.pose(-1.0 if n == 3 else 0.55)
				# Software renderers take long frames: pose the squash and the jump by hand.
				lobby.get_node("Buttons/Play").call("_set_press", 0.85 if n == 3 else 0.4)
				for p in [P1, P2]:
					var slot: Control = lobby.get_node("Spots/P%d/Character" % (p + 1))
					slot.position.y = slot.get("_base_y") - (55.0 if n == 3 else 20.0)
			else:
				lobby.count_step(1.0)
				wipe.pose(1.0 if n == 5 else 1.42, 1.0)
