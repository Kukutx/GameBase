extends RefCounted

## Content for a test of the foundation, which must not depend on any game's
## content: a registry with the running game's kinds of content that indexes
## only the entries the test builds. `use()` makes it what the content classes'
## `find()` and `find_all()` read for the rest of the test; when the test ends
## and GUT frees it, `ContentDB` is the active registry again.
##
##     const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
##
##     func before_each() -> void:
##         ContentFixture.use(self, [ContentFixture.item(&"apple")])

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
