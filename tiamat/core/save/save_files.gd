class_name SaveFiles
extends RefCounted

## The save files of a save manager on disk. What a file holds is read once
## and kept until the file changes (its time or its length), or until what
## makes a save usable changes (the `version` a read is asked with: the
## registered sections, the content), so a menu that asks whether a slot has a
## save reads no file again. Saves are compact JSON with every digit, so a
## float comes back as it was saved.

# func(data: Dictionary) -> bool: whether a save is one this build loads.
var _usable: Callable
# path -> {"stamp", "version", "data"}, `data` the usable save or {}.
var _read: Dictionary[String, Dictionary] = {}

func _init(usable: Callable) -> void:
	_usable = usable

## The save at `path` when it is one this build loads, else {}: read again
## only when the file changed since, or `version` (what decides whether a
## save is usable) differs from the last read's.
func read_usable(path: String, version: Array) -> Dictionary:
	var stamp := _file_stamp(path)
	var known: Dictionary = _read.get(path, {})
	if not known.is_empty() and known["stamp"] == stamp and known["version"] == version:
		return known["data"]
	var data := _read_dictionary(path) if not stamp.is_empty() else {}
	if not bool(_usable.call(data)):
		data = {}
	_read[path] = {"stamp": stamp, "version": version, "data": data}
	return data

## Writes `data` to `path`; false when it could not be written.
func write(path: String, data: Dictionary) -> bool:
	if path.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_read.erase(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(JSON.stringify(data, "", false, true))
	file.close()
	return stored

## Renames the file at `from` over the one at `to`; what was read of it moves
## along.
func move(from: String, to: String) -> Error:
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(to))
	_read.erase(to)
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
	if error == OK and _read.has(from):
		_read[to] = _read[from]
	_read.erase(from)
	return error

## Deletes the files at `paths`; false when one that exists could not be.
func delete(paths: PackedStringArray) -> bool:
	var ok := true
	for path: String in paths:
		_read.erase(path)
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and ok
	return ok

## Whether a file stands at any of `paths`.
static func any_exists(paths: PackedStringArray) -> bool:
	for path: String in paths:
		if not path.is_empty() and FileAccess.file_exists(path):
			return true
	return false

# When the file at `path` last changed and how long it is, which tell a file
# changed outside the game; empty for no file.
static func _file_stamp(path: String) -> Array[int]:
	var file := FileAccess.open(path, FileAccess.READ) if not path.is_empty() and FileAccess.file_exists(path) else null
	if file == null:
		return []
	return [FileAccess.get_modified_time(path), file.get_length()]

static func _read_dictionary(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
