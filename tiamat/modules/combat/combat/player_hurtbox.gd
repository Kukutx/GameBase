class_name PlayerHurtbox
extends Hurtbox

## The player's hurtbox (`Hurtbox`), of the player's faction: a hit takes the
## player's health (`CombatSettings.health_vital_id`), staggers the player
## while its knockback carries them (`TopDownPlayer.stagger()`), plays `hurt`
## on the player's `TopDownPlayer.actor_visual` (`death` when it took the last
## of it), shakes the screen (`GameCamera.shake_view()`) and is announced as
## `CombatEvents.player_hurt`. An affliction's tick (`Hurtbox.ailed`, a burn,
## a poison) takes health and is announced the same way, but neither staggers
## the player nor shakes the screen; one taking hold is told in a toast, and
## any change to them is announced as `CombatEvents.player_afflictions_changed`
## (which `AfflictionLine` shows). One that slows (`AfflictionData.speed_scale`)
## slows the player's steps while it lasts, through the
## `TopDownPlayer.MOVE_SPEED_STAT` stat, of which the hurtbox is a source
## (`GameStats`), and the `AFFLICTION_SECONDS_STAT` stat makes one last shorter
## on the player, or not at all. Eating or drinking an item tagged an
## affliction's `AfflictionData.cure_tag` lifts it (`ItemsEvents.item_consumed`,
## an antidote's poison), told in a toast; such an item is wanted while the
## affliction is on (`would_cure()`) even when it restores nothing the player
## lacks. A player without health left, or passing out, takes no more hits and
## no more ticks. A child of the player.
##
## The player chooses how hard hits land on them in the settings
## (`DAMAGE_TAKEN_OPTION`, which the combat module declares), read at each
## hit: a light choice halves a hit, a heavy one adds half again. Armour, a
## buff or a boon changes the `INCOMING_DAMAGE_STAT` stat, which a hit is
## changed by after that.

const SHAKE_STRENGTH := 3.0
const SHAKE_SECONDS := 0.2
## The player's option of how hard hits land (`GameOption`): one of the
## choices of `DAMAGE_TAKEN_SCALES`. A game that replaces the option with
## choices of its own takes a hit whole on a choice not named here.
const DAMAGE_TAKEN_OPTION := &"damage_taken"
const DAMAGE_TAKEN_SCALES: Dictionary[String, float] = {"Light": 0.5, "Standard": 1.0, "Heavy": 1.5}
## The stat a hit on the player is changed by (`GameStats`): 0.8 takes a fifth
## less.
const INCOMING_DAMAGE_STAT := &"incoming_damage"
## The stat a game's health vital may follow (`VitalData.maximum_stat`): a
## bonus of 20 is 20 more health at most.
const MAX_HEALTH_STAT := &"max_health"
## The stat what a defeated enemy drops is changed by (`GameStats`): 1.5 drops
## half again as much, the fraction rounded by chance.
const LOOT_STAT := &"loot_quantity"
## The stat how long an affliction lasts on the player is changed by
## (`GameStats`): 0.5 lasts half as long, 0 never takes hold.
const AFFLICTION_SECONDS_STAT := &"affliction_seconds"

func _init() -> void:
	faction = FactionData.PLAYER
	invincible_seconds = 0.6

func _ready() -> void:
	super()
	hurt.connect(_on_hurt)
	ailed.connect(_take)
	afflicted.connect(func(affliction: AfflictionData) -> void: GameEvents.toastf("Afflicted: %s", [affliction.display_name]))
	afflictions_changed.connect(CombatEvents.player_afflictions_changed.emit)
	slowed.connect(GameStats.notify_changed.unbind(1))
	ItemsEvents.item_consumed.connect(_on_item_consumed)

func _enter_tree() -> void:
	GameStats.register_source(self)

func _exit_tree() -> void:
	GameStats.unregister_source(self)

## Its change to the player's stats (`GameStats`): the player's steps slowed
## while an affliction that slows is on them.
func get_stat_multiplier(stat: StringName) -> float:
	return get_speed_scale() if stat == TopDownPlayer.MOVE_SPEED_STAT else 1.0

func get_stat_bonus(_stat: StringName) -> float:
	return 0.0

func can_be_hurt_by(damage: Damage) -> bool:
	return is_standing() and not GameSession.is_passing_out() and super(damage)

func get_affliction_scale(_affliction: AfflictionData) -> float:
	return maxf(GameStats.get_multiplier(AFFLICTION_SECONDS_STAT), 0.0)

func can_ail() -> bool:
	return is_standing() and not GameSession.is_passing_out() and super()

## The player's hurtbox: the `PlayerHurtbox` of the node in the "player" group,
## or null.
static func find_player() -> PlayerHurtbox:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return Hurtbox.of(tree.get_first_node_in_group(&"player")) as PlayerHurtbox

## Whether eating or drinking `item` now would lift an affliction on the player
## (`AfflictionData.cure_tag`): the combat module's use of what the player eats
## (`ItemData.register_consume_need()`).
static func would_cure(item: ItemData) -> bool:
	var player := find_player()
	return player != null and not player.find_cured_by(item).is_empty()

## The afflictions eating or drinking `item` lifts from the player, as the
## player reads it before buying or using it ("Cures Poisoned",
## `ItemData.register_effect_text()`): those whose `AfflictionData.cure_tag` it
## has; nothing for an item that cures none.
static func describe_cures(item: ItemData) -> PackedStringArray:
	var names := PackedStringArray()
	for affliction: AfflictionData in AfflictionData.find_all():
		if not affliction.cure_tag.is_empty() and item.has_tag(affliction.cure_tag):
			names.append(TranslationServer.translate(affliction.display_name))
	if names.is_empty():
		return PackedStringArray()
	return PackedStringArray([String(TranslationServer.translate("Cures %s")) % GameText.list(names)])

## Problems of the whole content (`ContentRegistry.register_check()`): an
## affliction cured by a tag no item has, so nothing can cure it.
static func find_cure_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	var tags := {}
	for item: ItemData in registry.get_entries(ItemData.KIND):
		for tag: String in item.tags:
			tags[tag] = true
	for affliction: AfflictionData in registry.get_entries(AfflictionData.KIND):
		if not affliction.cure_tag.is_empty() and not tags.has(affliction.cure_tag):
			problems.append("affliction '%s' is cured by items tagged '%s', which no item is" % [affliction.id, affliction.cure_tag])
	return problems

## Whether the player still stands: they have health left, or the game gives
## them none to lose (`CombatSettings.health_vital_id`).
static func is_standing() -> bool:
	var health := CombatSettings.current().health_vital_id
	return not Vitals.has_vital(health) or Vitals.get_value(health) > 0

## The health a hit of `amount` takes from the player at their choice of
## damage taken (`DAMAGE_TAKEN_OPTION`), changed by the `INCOMING_DAMAGE_STAT`
## stat, rounded, and at least 1 of a hit that does any.
static func damage_taken(amount: int) -> int:
	if amount <= 0:
		return amount
	var scaled := amount * GameSettings.options.scale_of(DAMAGE_TAKEN_OPTION, DAMAGE_TAKEN_SCALES)
	return maxi(1, roundi(GameStats.apply(INCOMING_DAMAGE_STAT, scaled)))

func _on_hurt(damage: Damage) -> void:
	var player := get_parent() as TopDownPlayer
	if player != null:
		player.stagger(get_knockback_left())
	if _take(damage) > 0:
		GameCamera.shake_view(self, SHAKE_STRENGTH, SHAKE_SECONDS)

func _on_item_consumed(item_id: StringName) -> void:
	for affliction: AfflictionData in find_cured_by(ItemData.find(item_id)):
		lift(affliction.id)
		GameEvents.toastf("Cured: %s", [affliction.display_name])

# Takes the health `damage` takes from the player, plays it on their visual
# and announces it; the health taken.
func _take(damage: Damage) -> int:
	var player := get_parent() as TopDownPlayer
	var health := CombatSettings.current().health_vital_id
	var taken := Vitals.drain(health, damage_taken(damage.amount))
	if taken <= 0:
		return 0
	if player != null and player.actor_visual != null:
		player.actor_visual.play_action(&"death" if Vitals.get_value(health) <= 0 else &"hurt")
	CombatEvents.player_hurt.emit(taken)
	return taken
