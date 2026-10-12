extends SceneTree

## What the runtime smokes of every game share. A script under a game's
## `test/runtime/`, which validation runs as the main loop, extends this file
## by its path, since a main loop compiles before the autoloads exist and
## names no class: `extends "res://gamebase/core/test/runtime_smoke.gd"`. It
## sets `smoke_name` and `save_directory` in `_init()` and writes its steps in
## `_run()`. The smoke reads English text, keeps its saves and profile in
## `save_directory` (deleted before and after), and quits with 1 when a check
## failed.

## The name the smoke reports itself by.
var smoke_name := "Runtime smoke"
## Where the smoke keeps its saves and profile.
var save_directory := "user://runtime_smoke"

var _failed := false

func _initialize() -> void:
	_run_smoke.call_deferred()

## The smoke's steps.
func _run() -> void:
	await process_frame

## Records a failure when `condition` does not hold.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error("%s: %s" % [smoke_name, message])

## Waits until the travel to `scene_path` is over: false when it is not over
## within `frames` frames.
func _arrive(scene_path: String, frames := 300) -> bool:
	var travel := root.get_node("WorldTravel")
	for _frame: int in frames:
		if current_scene != null and current_scene.scene_file_path == scene_path and not travel.is_traveling():
			await process_frame
			return true
		await process_frame
	_fail("Did not arrive at %s" % scene_path)
	return false

## Puts the player on `portal` (a `ScenePortal`) once portals take the
## player again after an arrival, so the player walks through it.
func _walk_into(portal: Node2D) -> void:
	var travel := root.get_node("WorldTravel")
	var deadline := Time.get_ticks_msec() + 3000
	while not bool(travel.call("can_enter_portal")) and Time.get_ticks_msec() < deadline:
		await process_frame
	(get_first_node_in_group("player") as Node2D).global_position = portal.global_position

## Uses `interactable` as the player does.
func _use(interactable: Node) -> void:
	interactable.call("interact", get_first_node_in_group("player"))

## Deletes the smoke's saves and profile.
func _cleanup() -> void:
	var save_manager := root.get_node("SaveManager")
	var slot_count := int((save_manager.get_script() as Script).get_script_constant_map().get("SLOT_COUNT", 1))
	for slot in range(1, slot_count + 1):
		save_manager.delete_slot(slot)
	# Written first, so nothing waits to be written when the smoke quits.
	var profile := root.get_node("GameProfile")
	profile.call("write_now")
	var profile_path := String(profile.get("profile_path"))
	for path: String in [profile_path, profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run_smoke() -> void:
	# The checks compare text with the English source strings.
	root.get_node("GameSettings").set("locale", "en")
	TranslationServer.set_locale("en")
	# Travels change scenes behind the transition as in play, without its fades.
	root.get_node("Transition").set("fade_seconds", 0.0)
	var save_manager := root.get_node("SaveManager")
	save_manager.save_directory = save_directory
	save_manager.select_slot(1)
	var profile := root.get_node("GameProfile")
	profile.set("profile_path", save_directory.path_join("profile.json"))
	_cleanup()
	profile.call("load_profile")
	await _run()
	_cleanup()
	if _failed:
		quit(1)
		return
	print("%s passed." % smoke_name)
	quit(0)
