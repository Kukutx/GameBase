class_name SkillManager
extends Node

signal skill_xp_changed(skill: StringName, xp: int, level: int)
signal skill_leveled_up(skill: StringName, level: int)

const FARMING := &"farming"
const FORAGING := &"foraging"
const SOCIAL := &"social"
const FISHING := &"fishing"
const MINING := &"mining"
const COMBAT := &"combat"
const SKILL_IDS: Array[StringName] = [FARMING, FORAGING, FISHING, MINING, COMBAT, SOCIAL]
## The name a skill is shown by, before translation.
const SKILL_NAMES := {
	FARMING: "Farming",
	FORAGING: "Foraging",
	FISHING: "Fishing",
	MINING: "Mining",
	COMBAT: "Combat",
	SOCIAL: "Social",
}
const LEVEL_THRESHOLDS := [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200]
const LEVEL_ENTITLEMENT_PREFIX := "__level:"

var _xp: Dictionary = {
	"farming": 0,
	"foraging": 0,
	"social": 0,
	"fishing": 0,
	"mining": 0,
	"combat": 0,
}
var _earned_levels: Dictionary = {
	"farming": 1,
	"foraging": 1,
	"social": 1,
	"fishing": 1,
	"mining": 1,
	"combat": 1,
}
var _events: Node

func _ready() -> void:
	_events = get_node_or_null("/root/GameEvents")
	if _events == null:
		return
	_events.connect("crop_harvested", Callable(self, "_on_crop_harvested"))
	_events.connect("item_foraged", Callable(self, "_on_item_foraged"))
	_events.connect("gift_given", Callable(self, "_on_gift_given"))
	_events.connect("npc_talked", Callable(self, "_on_npc_talked"))
	_events.connect("fish_caught", Callable(self, "_on_fish_caught"))
	_events.connect("resource_mined", Callable(self, "_on_resource_mined"))
	_events.connect("enemy_defeated", Callable(self, "_on_enemy_defeated"))

func add_xp(skill: StringName, amount: int) -> int:
	if not SKILL_IDS.has(skill):
		return 0
	if amount <= 0:
		return get_xp(skill)
	var key := String(skill)
	var old_level := get_level(skill)
	var next := get_xp(skill) + amount
	_xp[key] = next
	var xp_level := _get_level_from_xp(next)
	_earned_levels[key] = maxi(int(_earned_levels.get(key, 1)), xp_level)
	var level := get_level(skill)
	skill_xp_changed.emit(skill, next, level)
	if level > old_level:
		skill_leveled_up.emit(skill, level)
		if _events != null:
			_events.call("toastf", "%s reached level %d", [SKILL_NAMES[skill], level])
	return next

## The skill's translated name.
func get_skill_name(skill: StringName) -> String:
	return tr(String(SKILL_NAMES.get(skill, skill)))

func get_xp(skill: StringName) -> int:
	return maxi(int(_xp.get(String(skill), 0)), 0)

func get_level(skill: StringName) -> int:
	var key := String(skill)
	return maxi(_get_level_from_xp(get_xp(skill)), clampi(int(_earned_levels.get(key, 1)), 1, LEVEL_THRESHOLDS.size()))

func _get_level_from_xp(xp: int) -> int:
	var level := 1
	for index in range(1, LEVEL_THRESHOLDS.size()):
		if maxi(xp, 0) >= int(LEVEL_THRESHOLDS[index]):
			level = index + 1
		else:
			break
	return level

func get_perk_tier(skill: StringName) -> int:
	var level := get_level(skill)
	if level >= 10:
		return 2
	if level >= 5:
		return 1
	return 0

func get_energy_multiplier(skill: StringName) -> float:
	return 1.0 - 0.10 * float(get_perk_tier(skill))

func get_fishing_wait_multiplier() -> float:
	return 1.0 - 0.10 * float(get_perk_tier(FISHING))

func get_fishing_window_multiplier() -> float:
	return 1.0 + 0.15 * float(get_perk_tier(FISHING))

func get_combat_damage_multiplier() -> float:
	return 1.0 + (0.10 if get_perk_tier(COMBAT) == 1 else 0.25 if get_perk_tier(COMBAT) >= 2 else 0.0)

func get_friendship_multiplier() -> float:
	return 1.0 + 0.10 * float(get_perk_tier(SOCIAL))

func get_forage_quantity_bonus() -> int:
	return get_perk_tier(FORAGING)

func get_perk_summary(skill: StringName) -> String:
	var tier := get_perk_tier(skill)
	if tier <= 0:
		return tr("Next passive at Lv5")
	var rank := "II" if tier >= 2 else "I"
	match skill:
		FARMING:
			return tr("Field Efficiency %s · tool energy -%d%%") % [rank, tier * 10]
		FORAGING:
			return tr("Gatherer %s · +%d forage quantity") % [rank, tier]
		FISHING:
			return tr("Angler %s · bite wait -%d%% · reel window +%d%%") % [rank, tier * 10, tier * 15]
		MINING:
			return tr("Miner %s · mining energy -%d%%") % [rank, tier * 10]
		COMBAT:
			return tr("Fighter %s · attack +%d%% · attack energy -%d%%") % [rank, 25 if tier >= 2 else 10, tier * 10]
		SOCIAL:
			return tr("Neighbor %s · positive gift friendship +%d%%") % [rank, tier * 10]
		_:
			return tr("Passive tier %d") % tier

func get_summary() -> String:
	return tr("Farm %d · Forage %d · Fish %d · Mine %d · Combat %d · Social %d") % [get_level(FARMING), get_level(FORAGING), get_level(FISHING), get_level(MINING), get_level(COMBAT), get_level(SOCIAL)]

func reset_new_game() -> void:
	_xp = {"farming": 0, "foraging": 0, "social": 0, "fishing": 0, "mining": 0, "combat": 0}
	_earned_levels = {"farming": 1, "foraging": 1, "social": 1, "fishing": 1, "mining": 1, "combat": 1}
	for skill: StringName in SKILL_IDS:
		skill_xp_changed.emit(skill, 0, 1)

func to_save_data() -> Dictionary:
	var data: Dictionary = {}
	for skill: StringName in SKILL_IDS:
		var key := String(skill)
		data[key] = get_xp(skill)
		data[LEVEL_ENTITLEMENT_PREFIX + key] = clampi(int(_earned_levels.get(key, 1)), 1, LEVEL_THRESHOLDS.size())
	return data

func load_save_data(data: Dictionary) -> void:
	_xp = {"farming": 0, "foraging": 0, "social": 0, "fishing": 0, "mining": 0, "combat": 0}
	_earned_levels = {"farming": 1, "foraging": 1, "social": 1, "fishing": 1, "mining": 1, "combat": 1}
	for raw_key: Variant in data.keys():
		var key := String(raw_key)
		if key.begins_with(LEVEL_ENTITLEMENT_PREFIX):
			var skill_key := StringName(key.trim_prefix(LEVEL_ENTITLEMENT_PREFIX))
			if SKILL_IDS.has(skill_key):
				_earned_levels[String(skill_key)] = clampi(_safe_int(data[raw_key], 1), 1, LEVEL_THRESHOLDS.size())
			continue
		var skill := StringName(key)
		if SKILL_IDS.has(skill):
			_xp[key] = maxi(_safe_int(data[raw_key], 0), 0)
	# A level once earned stays earned; easier thresholds can only raise it.
	for skill: StringName in SKILL_IDS:
		var key := String(skill)
		_earned_levels[key] = maxi(int(_earned_levels.get(key, 1)), _get_level_from_xp(get_xp(skill)))
		skill_xp_changed.emit(skill, get_xp(skill), get_level(skill))

func _on_crop_harvested(_crop_id: StringName, _item_id: StringName, quantity: int) -> void:
	add_xp(FARMING, 25 * maxi(quantity, 1))

func _on_item_foraged(_item_id: StringName, quantity: int) -> void:
	add_xp(FORAGING, 10 * maxi(quantity, 1))

func _on_gift_given(_npc_id: StringName, _item_id: StringName, friendship_delta: int) -> void:
	if friendship_delta > 0:
		add_xp(SOCIAL, 15)

func _on_npc_talked(_npc_id: StringName) -> void:
	add_xp(SOCIAL, 2)

func _on_fish_caught(_fish_id: StringName, _item_id: StringName) -> void:
	add_xp(FISHING, 20)

func _on_resource_mined(_node_id: StringName, _item_id: StringName, quantity: int) -> void:
	add_xp(MINING, 12 * maxi(quantity, 1))

func _on_enemy_defeated(_enemy_id: StringName, combat_xp: int) -> void:
	add_xp(COMBAT, maxi(combat_xp, 1))

func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback
