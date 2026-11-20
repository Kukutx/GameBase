class_name WeaponUse
extends RefCounted

## What the player's weapons share (`MeleeAttack` swings them, `RangedAttack`
## shoots them): a weapon is the item selected in the hotbar, a tool whose
## action its attack handles. It hits for its power changed by the
## `DAMAGE_STAT` stat, and each attack costs its share of the game's attack
## vital (`CombatSettings.attack_vital_id`) changed by the `COST_STAT` stat.

## The stat that changes how hard the player's weapons hit.
const DAMAGE_STAT := &"attack_damage"
## The stat that changes what the player's attacks cost.
const COST_STAT := &"attack_cost"

## The weapon selected in the hotbar when its tool action is `action`, or null.
static func selected(action: StringName) -> ItemData:
	var weapon := Hotbar.get_selected_item()
	if weapon == null or not weapon.is_tool() or weapon.tool_action != action:
		return null
	return weapon

## How hard `weapon` hits now: at least 1.
static func damage_of(weapon: ItemData) -> int:
	if weapon == null:
		return 0
	return maxi(roundi(GameStats.apply(DAMAGE_STAT, weapon.tool_power)), 1)

## The affliction a hit of `weapon` lays now (`AfflictionData`): the first by
## id whose `AfflictionData.weapon_tag` it carries, else the first by id that
## a roll of its `AfflictionData.chance_stat` lays (`rolls_chance()`), or null.
static func affliction_of(weapon: ItemData) -> AfflictionData:
	if weapon == null:
		return null
	var tagged := tagged_affliction_of(weapon)
	if tagged != null:
		return tagged
	for affliction: AfflictionData in AfflictionData.find_all():
		if affliction.rolls_chance():
			return affliction
	return null

## The affliction every hit of `weapon` lays: the first by id whose
## `AfflictionData.weapon_tag` it carries, or null.
static func tagged_affliction_of(weapon: ItemData) -> AfflictionData:
	for affliction: AfflictionData in AfflictionData.find_all():
		if not affliction.weapon_tag.is_empty() and weapon.has_tag(affliction.weapon_tag):
			return affliction
	return null

## What `item` does as a weapon, as the player reads it before buying or using
## it (`ItemData.register_effect_text()`): how hard it hits now ("Attack 12"),
## beside the hardest hitting other weapon of its kind the player carries
## (`rival_of()`: "Attack 12 (+4 vs. your Iron Sword)"), and the affliction
## every hit of it lays; nothing for an item neither attack swings or shoots.
static func describe(item: ItemData) -> PackedStringArray:
	var lines := PackedStringArray()
	if item.tool_action != MeleeAttack.TOOL_ACTION and item.tool_action != RangedAttack.TOOL_ACTION:
		return lines
	var damage := damage_of(item)
	var rival := rival_of(item)
	if rival == null:
		lines.append(String(TranslationServer.translate("Attack %d")) % damage)
	else:
		lines.append(String(TranslationServer.translate("Attack %d (%+d vs. your %s)")) % [
			damage, damage - damage_of(rival), TranslationServer.translate(rival.display_name)])
	var tagged := tagged_affliction_of(item)
	if tagged != null:
		lines.append(String(TranslationServer.translate("Its hits leave foes %s")) % TranslationServer.translate(tagged.display_name))
	return lines

## The other weapon the player carries that `weapon` is weighed against: of
## the same tool action, the one that hits hardest now (the first by id of
## those that hit as hard), or null when they carry no other.
static func rival_of(weapon: ItemData) -> ItemData:
	var rival: ItemData = null
	for carried: ItemData in InventoryState.find_tools(weapon.tool_action):
		if carried.id != weapon.id and (rival == null or damage_of(carried) > damage_of(rival)):
			rival = carried
	return rival

## What an attack that costs `cost` takes of the attack vital now: none for
## none, else at least 1.
static func cost_of(cost: int) -> int:
	if cost <= 0:
		return 0
	return maxi(int(floor(float(cost) * GameStats.get_multiplier(COST_STAT))), 1)

## Pays for an attack with `weapon` that costs `cost`: false, with a word to
## the player, when they no longer carry it or lack the vital for it.
static func pay(weapon: ItemData, cost: int) -> bool:
	if not InventoryState.has_item(weapon.id, 1):
		GameEvents.toastf("You do not have %s", [weapon.display_name])
		return false
	return Vitals.try_spend(CombatSettings.current().attack_vital_id, cost_of(cost))

## Plays the attack of `actor`'s animated look (its `ActorVisual`), if it has one.
static func play_attack(actor: Node) -> void:
	var visual := actor.get_node_or_null("ActorVisual") as DirectionalActorVisual if actor != null else null
	if visual != null:
		visual.play_action(&"attack")
