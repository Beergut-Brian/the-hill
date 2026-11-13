## -- --ui=<state> for New Hill screenshots (scripts/tools/shots.sh), next to the kit's UiPreview:
##   lobby-saved     a saved hill: Continue focused, New Hill under it
##   lobby-newhill   New Hill's question, A held about half way
##   lobby-fresh     just after confirming: Play only, "BRAND NEW HILL!"
##   lobby-restore   Settings with Restore last hill focused
##   newhill-play    confirmed, then into the game: the fresh hill
## Runs in its own scratch saves folder and profile (user://ui_preview_saves, "ui_preview"), seeded
## with a made-up hill, so a screenshot never touches a real save or its backups.
class_name NewHillPreview
extends RefCounted

const STATES := ["lobby-saved", "lobby-newhill", "lobby-fresh", "lobby-restore", "newhill-play"]
const DIR := "user://ui_preview_saves"


static func run(lobby: Control) -> void:
	var s := UiPreview.state_from_args(OS.get_cmdline_user_args())
	if not STATES.has(s) or Game.demo:
		return
	seed_save()
	lobby.refresh_save_state()
	lobby.get_node("Backdrop").apply_skin()
	lobby.freeze = true
	Players.join_virtual(Players.P1)
	Players.join_virtual(Players.P2)
	lobby.set_ready(Players.P1, false, true)
	lobby.set_ready(Players.P2, false, true)
	lobby.focus_item(lobby.Choice.PLAY)
	var tree := lobby.get_tree()
	await tree.create_timer(0.6).timeout
	match s:
		"lobby-newhill":
			lobby.focus_item(lobby.Choice.NEW)
			lobby.press_a(Players.P1)
			await tree.create_timer(0.4).timeout
			var q: HoldConfirm = lobby.new_hill
			q.move_focus(1)
			q.press_a()
			q.hold_step(true, HoldConfirm.HOLD_TIME * 0.6)
			q.freeze = true
		"lobby-fresh", "newhill-play":
			lobby.focus_item(lobby.Choice.NEW)
			lobby.press_a(Players.P1)
			var q: HoldConfirm = lobby.new_hill
			q.move_focus(1)
			q.press_a()
			q.hold_step(true, HoldConfirm.HOLD_TIME + 0.01)
			if s == "newhill-play":
				await tree.create_timer(0.5).timeout
				lobby.freeze = false
				Game.finish_lobby([Players.P1, Players.P2])
		"lobby-restore":
			# A backup to restore, and a hill being played now.
			Save.start_new()
			seed_save(false)
			lobby.refresh_save_state()
			lobby.focus_item(lobby.Choice.SETTINGS)
			lobby.press_a(Players.P1)
			var st: SettingsPanel = lobby.get_node("Settings")
			await tree.create_timer(0.3).timeout
			st.move_focus(1)
			st.move_focus(1)
			st.move_focus(1)
			st.move_focus(1)


## A made-up hill in the scratch profile: some buildings, down to Stone, two treasures.
static func seed_save(clear := true) -> void:
	if clear:
		DirAccess.make_dir_recursive_absolute(DIR)
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute("%s/%s" % [DIR, f])
	Save.saves_dir = DIR
	Save.use_profile("ui_preview")
	Save.set_value("buildings", [{"id": "house", "cell": [4, 0]}, {"id": "shop", "cell": [12, 0]},
			{"id": "house", "cell": [20, 0]}])
	Save.set_value("players", [{"deepest": 2, "scene": "hillville"}, {"deepest": 1, "scene": "hillville"}])
	Save.set_value("treasures", ["fossil", "old_coin"])
	Save.flush()
