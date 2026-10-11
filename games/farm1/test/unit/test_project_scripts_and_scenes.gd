extends GutTest

# The import step compiles no gameplay script, so a syntax or type error in a
# script that no other test happens to load would reach a release unnoticed.
# Loading every script and scene compiles them here. A script that does not
# compile also makes the engine print a SCRIPT ERROR line, which fails the step.

const PROJECT_ROOTS: Array[String] = ["res://gamebase", "res://game"]

func test_every_game_script_compiles() -> void:
	var paths := _collect_roots(".gd")
	for path: String in paths:
		var script := load(path) as GDScript
		assert_not_null(script, "%s did not load" % path)
		if script != null:
			assert_true(script.can_instantiate(), "%s did not compile" % path)

func test_every_game_scene_instantiates() -> void:
	var paths := _collect_roots(".tscn")
	for path: String in paths:
		var scene := load(path) as PackedScene
		assert_not_null(scene, "%s did not load" % path)
		if scene == null:
			continue
		assert_true(scene.can_instantiate(), "%s cannot be instantiated" % path)
		var node := scene.instantiate()
		assert_not_null(node, "%s did not instantiate" % path)
		if node != null:
			node.free()

func _collect_roots(extension: String) -> PackedStringArray:
	var result := PackedStringArray()
	for root: String in PROJECT_ROOTS:
		var found := _collect(root, extension)
		assert_gt(found.size(), 0, "No %s files found under %s" % [extension, root])
		result.append_array(found)
	return result

func _collect(directory: String, extension: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(directory)
	# Godot does not import a directory with a .gdignore, so neither does
	# this test.
	if dir == null or dir.file_exists(".gdignore"):
		return result
	for name: String in dir.get_directories():
		if not name.begins_with("."):
			result.append_array(_collect(directory.path_join(name), extension))
	for name: String in dir.get_files():
		if name.ends_with(extension):
			result.append(directory.path_join(name))
	return result
