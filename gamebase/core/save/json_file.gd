class_name JsonFile
extends RefCounted

## A JSON file outside the save slots (the profile, a legacy) that is replaced
## whole: written beside itself first and then renamed over the old one, so a
## crash leaves the old file or the new one, never half a file.

## Writes `data` as JSON to `path`; what went wrong, or "".
static func write(path: String, data: Variant) -> String:
	var temp_path := path + ".tmp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return "could not write '%s' (%d)" % [temp_path, FileAccess.get_open_error()]
	var stored := file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if not stored:
		return "could not write '%s'" % temp_path
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var renamed := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
	return "" if renamed == OK else "could not replace '%s' (%d)" % [path, renamed]

## What the file at `path` holds, or the written copy a crash kept from
## replacing it; null when there is neither or it holds no JSON.
static func read(path: String) -> Variant:
	var source := path if FileAccess.file_exists(path) else path + ".tmp"
	if not FileAccess.file_exists(source):
		return null
	var json := JSON.new()
	return json.data if json.parse(FileAccess.get_file_as_string(source)) == OK else null

## Deletes the file at `path` and any written copy beside it.
static func remove(path: String) -> void:
	for file_path: String in [path, path + ".tmp"]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
