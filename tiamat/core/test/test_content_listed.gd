extends GutTest

## Every content entry a game keeps beside its content packs (the folder of
## each pack its `GameDefinition` names, and the folders under it) is in the
## running game's content (`ContentDB`): a file left out of the pack would be
## missing from the game with nothing to say so.

func test_every_content_file_of_the_game_is_in_its_content() -> void:
	var listed := {}
	for kind: StringName in ContentDB.get_kinds():
		for entry: Variant in ContentDB.get_entries(kind):
			listed[(entry as Resource).resource_path] = true
	var folders := {}
	for pack: ContentPack in GameDefinition.current().content:
		# A pack at the project's root would have every resource checked.
		if pack != null and pack.resource_path.get_base_dir() not in ["", "res:", "res://"]:
			folders[pack.resource_path.get_base_dir()] = true
	var left_out := PackedStringArray()
	for folder: String in folders:
		for path: String in _resource_files(folder):
			if load(path) is ContentEntry and not listed.has(path):
				left_out.append(path)
	assert_eq(left_out, PackedStringArray(), "content no content pack lists")

# The .tres files under `directory`, in its subdirectories too.
func _resource_files(directory: String) -> PackedStringArray:
	var files := PackedStringArray()
	if not DirAccess.dir_exists_absolute(directory):
		return files
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() == "tres":
			files.append(directory.path_join(file))
	for subdirectory: String in DirAccess.get_directories_at(directory):
		files.append_array(_resource_files(directory.path_join(subdirectory)))
	return files
