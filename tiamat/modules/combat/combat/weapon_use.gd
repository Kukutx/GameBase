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
