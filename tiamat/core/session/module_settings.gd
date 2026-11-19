class_name ModuleSettings
extends Resource

## What a game sets for one of its modules: a module defines a subclass with
## its own fields (`ItemsSettings`: the starting money and kit), and a game
## lists one of it in `GameDefinition.module_settings`. The module reads them
## with `GameDefinition.current().get_settings(ItemsSettings)`, usually through
## a static `current()` of the subclass; a game that lists none gets the
## subclass's defaults.

## What is wrong with the settings against `registry`'s content: an id that
## names nothing, a value out of range. Each problem reads after the settings'
## class name ("ItemsSettings: start item 'x' is no item"); the registry adds it.
func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	return PackedStringArray()
