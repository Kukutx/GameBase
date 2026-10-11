class_name SaveMigration
extends RefCounted

## Upgrades a save to the current `GameSaveManager.SAVE_VERSION` one version at
## a time, with the steps of the running game's `SaveMigrationSteps`
## (`GameDefinition.save_migrations`).

static func migrate(source: Dictionary, target_version: int) -> Dictionary:
	var data := source.duplicate(true)
	var version := maxi(_safe_int(data.get("version", 1), 1), 1)
	if version >= target_version:
		return data
	var steps := _steps()
	while version < target_version:
		steps.upgrade(version, data)
		version += 1
		data["version"] = version
	steps.finish_legacy_upgrade(data, target_version)
	return data

static func _steps() -> SaveMigrationSteps:
	var script := GameDefinition.current().save_migrations
	var steps: Variant = script.new() if script != null and script.can_instantiate() else null
	if steps is SaveMigrationSteps:
		return steps
	return SaveMigrationSteps.new()

static func _safe_int(value: Variant, fallback: int = 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback
