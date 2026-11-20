class_name CombatModule
extends GameModule

## Wires the combat module into the core (see `GameModule`): enemies, the
## weapons' tool action, the stats a melee attack and a hit on the player read, a fight that ends
## when the player is taken out of play, and the player's choice of how hard
## hits land on them (`PlayerHurtbox.DAMAGE_TAKEN_OPTION`), and the items that
## lift an affliction on them (`PlayerHurtbox.would_cure()`).

const OPTIONS: Array[String] = [
	"res://tiamat/modules/combat/options/damage_taken.tres",
	"res://tiamat/modules/combat/options/foe_strength.tres",
]

func install() -> void:
	ContentDB.register_kind(EnemyData.KIND, EnemyData)
	ContentDB.register_kind(EliteData.KIND, EliteData)
	ContentDB.register_settings(CombatSettings)
	ItemData.register_tool_action(MeleeAttack.TOOL_ACTION)
	ItemData.register_tool_action(RangedAttack.TOOL_ACTION)
	GameStats.register_stat(WeaponUse.DAMAGE_STAT, "Attack")
	GameStats.register_stat(WeaponUse.COST_STAT, "Attack energy cost")
	GameStats.register_stat(PlayerHurtbox.INCOMING_DAMAGE_STAT, "Damage Taken")
	GameStats.register_stat(PlayerHurtbox.MAX_HEALTH_STAT, "Max health")
	GameStats.register_stat(PlayerHurtbox.LOOT_STAT, "Loot")
	GameStats.register_stat(DodgeRoll.COOLDOWN_STAT, "Dodge cooldown")
	GameStats.register_stat(PlayerHurtbox.AFFLICTION_SECONDS_STAT, "Affliction length")
	GameSession.register_activity_end(FightState.end_fight)
	ItemData.register_consume_need(PlayerHurtbox.would_cure)
	ContentDB.register_check(PlayerHurtbox.find_cure_problems)
	ItemSources.register(&"enemy_drops", find_item_sources)
	if not CombatEvents.enemy_defeated.is_connected(Bestiary.record):
		CombatEvents.enemy_defeated.connect(Bestiary.record)
	if not CombatEvents.elite_defeated.is_connected(Bestiary.record_elite):
		CombatEvents.elite_defeated.connect(Bestiary.record_elite)
	PauseMenu.add_page(&"bestiary", "Bestiary", 30, Bestiary.describe)

func get_options() -> Array[GameOption]:
	var options: Array[GameOption] = []
	for path: String in OPTIONS:
		options.append(load(path) as GameOption)
	return options

## The ways to get items the module gives (`ItemSources`): what each enemy
## drops.
static func find_item_sources(registry: ContentRegistry, sources: ItemSources) -> void:
	for enemy: EnemyData in registry.get_entries(EnemyData.KIND):
		sources.add(enemy.drop_item_id, TranslationServer.translate("Dropped by %s") % TranslationServer.translate(enemy.display_name))
