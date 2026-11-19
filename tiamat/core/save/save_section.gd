class_name SaveSection
extends RefCounted

## One named part of a save file, owned by one service.
##
## A game registers its sections with `SaveManager.register_section()`; the
## save manager then writes, validates and restores them without knowing which
## services exist. `order` decides the restore order (lower first), because
## scene components read the restored services in `_ready()` and some services
## depend on others being restored first.

## Key of the section in the save dictionary.
var id: StringName
## Restore order; lower values are restored first.
var order: int
## `func() -> Dictionary` returning the section's current state.
var write: Callable
## `func(section: Dictionary, snapshot: Dictionary) -> void` restoring the state.
## `snapshot` is the whole save, for the rare section whose restore depends on
## another section (read it, never modify it).
var read: Callable

func _init(section_id: StringName, restore_order: int, write_callable: Callable, read_callable: Callable) -> void:
	id = section_id
	order = restore_order
	write = write_callable
	read = read_callable
