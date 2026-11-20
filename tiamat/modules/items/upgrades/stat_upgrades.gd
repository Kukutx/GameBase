class_name StatUpgrades
extends RefCounted

## The `GameStats` source of the world's lasting upgrades (`StatUpgradeData`):
## each changes the stats it names once for every level the world bought. The
## items module registers the one there is (`instance()`).

static var _instance: StatUpgrades = null

# The levels the world bought, upgrade id -> level, read again once the world
# changed them (the player's speed asks for its stat every frame).
var _levels: Dictionary[StringName, int] = {}
var _read := false

## The one source of the world's upgrades.
static func instance() -> StatUpgrades:
	if _instance == null:
		_instance = StatUpgrades.new()
		WorldState.changed.connect(_instance._on_world_changed)
	return _instance

## `GameStats` source: the product of the upgrades' multipliers of `stat`,
## each once for every level.
func get_stat_multiplier(stat: StringName) -> float:
	var result := 1.0
	var levels := _read_levels()
	for upgrade_id: StringName in levels:
		var upgrade := StatUpgradeData.find(upgrade_id)
		if upgrade != null and upgrade.multipliers.has(stat):
			result *= pow(upgrade.multipliers[stat], mini(levels[upgrade_id], upgrade.max_level))
	return result

## `GameStats` source: the sum of the upgrades' bonuses to `stat`, each once
## for every level.
func get_stat_bonus(stat: StringName) -> float:
	var result := 0.0
	var levels := _read_levels()
	for upgrade_id: StringName in levels:
		var upgrade := StatUpgradeData.find(upgrade_id)
		if upgrade != null:
			result += float(upgrade.bonuses.get(stat, 0.0)) * mini(levels[upgrade_id], upgrade.max_level)
	return result

func _read_levels() -> Dictionary[StringName, int]:
	if _read:
		return _levels
	_levels.clear()
	for key: StringName in WorldState.get_keys(StatUpgradeData.LEVEL_PREFIX):
		var level := WorldState.get_int(key)
		if level > 0:
			_levels[StringName(String(key).trim_prefix(StatUpgradeData.LEVEL_PREFIX))] = level
	_read = true
	return _levels

func _on_world_changed(key: StringName, _value: Variant) -> void:
	if key == &"" or String(key).begins_with(StatUpgradeData.LEVEL_PREFIX):
		_read = false
		GameStats.notify_changed()
