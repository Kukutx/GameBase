class_name ItemSources
extends RefCounted

## The ways the player gets each item, as they read them: sold at a shop,
## crafted, dropped by an enemy, grown, caught, mined, given for a quest. Each
## module that gives items adds its own ways with a finder it registers when
## it installs (`register()`), a function that takes the content
## (`ContentRegistry`) and this list and calls `add()` for each item it gives;
## a game adds its own ways (a chest of its world, a gift in a dialogue) the
## same way from its `GameSetup`. `gather()` asks every finder, an item's
## details list its ways (`get_ways()`), and a game's test finds an item the
## player has no way to get (`find_unobtainable()`).

## The finders, by the id of what registered them.
static var _finders: Dictionary[StringName, Callable] = {}

# Each item's ways, by item id.
var _ways: Dictionary[StringName, PackedStringArray] = {}

## Adds `finder`, a `func(registry: ContentRegistry, sources: ItemSources)`,
## under `id`; registering an id again replaces its finder.
static func register(id: StringName, finder: Callable) -> void:
	_finders[id] = finder

## Every way to get each item of `registry`'s content (the running game's
## when null), as the finders find them.
static func gather(registry: ContentRegistry = null) -> ItemSources:
	var sources := ItemSources.new()
	var content := registry if registry != null else ContentRegistry.active
	if content == null:
		return sources
	for finder: Callable in _finders.values():
		finder.call(content, sources)
	return sources

## The ways to get item `item_id` in the running game, as the player reads
## them.
static func describe(item_id: StringName) -> PackedStringArray:
	return gather().get_ways(item_id)

## Adds `way` (translated already) as a way to get item `item_id`; a way
## already listed is listed once.
func add(item_id: StringName, way: String) -> void:
	if item_id == &"" or way.is_empty():
		return
	var ways: PackedStringArray = _ways.get(item_id, PackedStringArray())
	if not ways.has(way):
		ways.append(way)
	_ways[item_id] = ways

## Adds `way` for each item id of `amounts` (item id -> count, as a reward
## lists them).
func add_each(amounts: Dictionary, way: String) -> void:
	for raw_id: Variant in amounts:
		add(StringName(String(raw_id)), way)

## The ways to get item `item_id`, in the order they were added.
func get_ways(item_id: StringName) -> PackedStringArray:
	return _ways.get(item_id, PackedStringArray())

## Whether the player has a way to get item `item_id`.
func has_way(item_id: StringName) -> bool:
	return _ways.has(item_id)

## The ids of the items of `registry` the player has no way to get.
func find_unobtainable(registry: ContentRegistry) -> PackedStringArray:
	var missing := PackedStringArray()
	for entry: ContentEntry in registry.get_entries(ItemData.KIND):
		if not has_way(entry.id):
			missing.append(String(entry.id))
	return missing

## "Name x2, Other" for `amounts` (item id -> count) of `registry`'s items,
## as a recipe lists what it takes.
static func describe_amounts(registry: ContentRegistry, amounts: Dictionary) -> String:
	var parts := PackedStringArray()
	for raw_id: Variant in amounts:
		var item := registry.get_entry(ItemData.KIND, StringName(String(raw_id))) as ItemData
		var item_name := String(TranslationServer.translate(item.display_name)) if item != null else String(raw_id)
		var count := int(amounts[raw_id])
		parts.append(item_name if count <= 1 else "%s x%d" % [item_name, count])
	return ", ".join(parts)
