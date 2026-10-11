class_name SaveSection
extends RefCounted

## One named part of a save file, owned by one service.
##
## A game registers its sections with `SaveManager.register_section()`; the
## save manager then writes, validates and restores them without knowing which
## services exist. `order` decides the restore order (lower first), because
## scene components read the restored services in `_ready()` and some services
## depend on others being restored first.

## Key of the section in the save dictionary. Never rename it: published saves
## store their data under this key.
var id: StringName
## Restore order; lower values are restored first.
var order: int
## First `GameSaveManager.SAVE_VERSION` whose saves must contain this section.
## Saves from an older version may lack it; `SaveMigration` gives them a default.
var since_version: int
## `func() -> Dictionary` returning the section's current state.
var write: Callable
## `func(section: Dictionary, snapshot: Dictionary) -> void` restoring the state.
## `snapshot` is the whole save, for the rare section whose restore depends on
## another section (read it, never modify it).
var read: Callable
## A save without this section restores it from an empty dictionary. When the
## section exists but is not a dictionary, `read` runs with an empty dictionary
## only if this is true; otherwise the service is left as it is.
var read_when_missing: bool

func _init(section_id: StringName, restore_order: int, required_since: int, write_callable: Callable, read_callable: Callable, read_missing := false) -> void:
	id = section_id
	order = restore_order
	since_version = required_since
	write = write_callable
	read = read_callable
	read_when_missing = read_missing
