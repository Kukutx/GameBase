extends "res://tiamat/core/test/runtime_smoke.gd"

## Plays Pocket Jianghu from its first scene: the boot starts a new game at the
## desk, the hero and the panel are there, an hour of play passes, the hero is
## saved and changed, and the load brings the hero back.

const DESK := "res://game/pet/desk.tscn"

func _init() -> void:
	smoke_name = "Pocket Jianghu smoke"
	save_directory = "user://jianghu_smoke"

func _run() -> void:
	change_scene_to_file("res://game/ui/boot.tscn")
	if not await _arrive(DESK):
		return
	var cultivation := root.get_node("Cultivation")
	var save_manager := root.get_node("SaveManager")
	_check(current_scene.get_node("Pet") != null, "The desk has no hero")
	var panel := current_scene.get_node("Panel") as Control
	_check(panel.visible, "The panel does not show in a window")
	cultivation.call("play_out", 3600.0)
	_check(int(cultivation.get("layer")) > 1, "An hour climbed no layer")
	_check(float(cultivation.get("silver")) > 0.0, "An hour of roaming won no silver")
	for page: int in 3:
		panel.call("show_page", page)
		await process_frame
	current_scene.call("_on_pet_clicked")
	_check(bool(cultivation.call("is_boosted")), "Clicking the hero did not encourage them")
	cultivation.call("_save")
	var layer := int(cultivation.get("layer"))
	var problem: String = save_manager.write_save()
	_check(problem.is_empty(), "Save failed: %s" % problem)
	cultivation.set("layer", 1)
	cultivation.call("_save")
	var loaded: bool = await save_manager.load_game()
	_check(loaded, "Load failed")
	await _arrive(DESK)
	_check(int(cultivation.get("layer")) == layer, "The load did not bring the hero back (layer %d)" % cultivation.get("layer"))
