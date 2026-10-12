extends RefCounted

## Content for a test of the foundation, which must not depend on any game's
## content: a registry with the running game's kinds of content that indexes
## only the entries the test builds. `use()` makes it what the content classes'
## `find()` and `find_all()` read for the rest of the test; when the test ends
## and GUT frees it, `ContentDB` is the active registry again. `add_stat()`
## lets fixture content change a stat no module registers, `use_calendar()`
## counts the days by a calendar whatever the game's is, and
## `with_definition()` starts a service on a fixture `GameDefinition`.
##
## GUT runs `after_each()` before it frees the registry, so a test that
## restores a service from its snapshot in `after_each()` makes `ContentDB`
## active first; otherwise the service would load its snapshot against the
## fixture content and drop what the game defines.
##
##     const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
##
##     func before_each() -> void:
##         _saved = WorldState.to_save_data()
##         ContentFixture.use(self, [_fixture_location()])
##
##     func after_each() -> void:
##         ContentRegistry.active = ContentDB
##         WorldState.load_save_data(_saved)

# The game's definition while `use_calendar()` stands in for it.
static var _running_definition: GameDefinition

## Makes `entries` the running game's only content until the test ends;
## returns their registry.
static func use(test: GutTest, entries: Array) -> ContentRegistry:
	var registry := ContentRegistry.new()
	for kind: StringName in ContentDB.get_kinds():
		registry.register_kind(kind, ContentDB.get_kind_script(kind))
	var pack := ContentPack.new()
	pack.entries.assign(entries)
	registry.packs = [pack]
	var problems := registry.index()
	test.assert_eq(problems, PackedStringArray(), "the fixture content indexes")
	# Outside the tree until now, the registry does not take the place of the
	# active one when it enters; it gives the place back to ContentDB when GUT
	# frees it (after its own _exit_tree() has cleared it).
	test.add_child_autofree(registry)
	registry.tree_exiting.connect(func() -> void: ContentRegistry.active = ContentDB)
	ContentRegistry.active = registry
	return registry

## Registers `stat` with `GameStats` until the test ends, so fixture content
## (a food buff, a skill perk) may change it.
static func add_stat(test: GutTest, stat: StringName) -> void:
	if GameStats.has_stat(stat):
		return
	GameStats.register_stat(stat)
	# Stats are registered for good when modules install; only a test takes
	# one back, when GUT frees this node.
	var holder := Node.new()
	test.add_child_autofree(holder)
	holder.tree_exiting.connect(func() -> void: GameStats._stats.erase(stat))

## Makes `calendar` the running game's calendar (`GameCalendar.current()`)
## until the test ends, for a test that counts by its seasons whatever calendar
## the game it runs in has.
## A test may call it again for another calendar.
static func use_calendar(test: GutTest, calendar: GameCalendar) -> void:
	if _running_definition == null:
		_running_definition = GameDefinition.current()
	var definition := _running_definition.duplicate() as GameDefinition
	definition.calendar = calendar
	GameDefinition._current = definition
	var holder := Node.new()
	test.add_child_autofree(holder)
	holder.tree_exiting.connect(_restore_definition)

## Calls `create` while `definition` is the running game's definition
## (`GameDefinition.current()`) and returns what it returns: for a service
## that reads the definition when it is created or enters the tree.
static func with_definition(definition: GameDefinition, create: Callable) -> Variant:
	var running := GameDefinition.current()
	GameDefinition._current = definition
	var result: Variant = create.call()
	GameDefinition._current = running
	return result

static func _restore_definition() -> void:
	if _running_definition != null:
		GameDefinition._current = _running_definition
		_running_definition = null
