class_name SaveMigrationSteps
extends RefCounted

## A game's save history: how a save of each older `GameSaveManager.SAVE_VERSION`
## is upgraded by one version. A game extends this class and names its script in
## `GameDefinition.save_migrations`; `SaveMigration` runs the steps in order.

## Upgrades `data` in place from `from_version` to `from_version + 1`.
func upgrade(_from_version: int, _data: Dictionary) -> void:
	pass

## Runs once after a save from an older version was upgraded to
## `target_version`, for defaults that depend on the whole history.
func finish_legacy_upgrade(_data: Dictionary, _target_version: int) -> void:
	pass
