class_name JianghuRules
extends RefCounted

## The numbers of Pocket Jianghu, as pure functions so tests pin them: what a
## layer of cultivation costs, how fast the hero cultivates, how strong they
## and their foes are, and how a fight goes.
##
## The hero's stage is the count of layers climbed in all: realm × `LAYERS` +
## layer − 1. A foe's level is where it is met: region × `LAYERS` plus a part
## of a level for each fight already won there, and the boss a little above
## the region's last layer, so the hero needs most of a realm and some martial
## arts to beat it.

## Layers in every realm.
const LAYERS := 9
## Foes beaten in a region before its boss comes.
const REGION_FIGHTS := 10

const LAYER_COST_BASE := 25.0
const LAYER_COST_GROWTH := 1.45
const QI_RATE_GROWTH := 1.25
const POWER_GROWTH := 1.14
const FOE_GROWTH := 1.153
const HERO_ATTACK := 8.0
const HERO_HEALTH := 50.0
const FOE_ATTACK := 5.0
const FOE_HEALTH := 30.0
const FOE_LEVEL_PER_FIGHT := 0.8
const BOSS_LEVEL := 8.5
const BOSS_HEALTH := 1.6
const BOSS_ATTACK := 1.2
const BOSS_SILVER := 10.0
const SILVER_BASE := 4.0
const SILVER_GROWTH := 1.15
## Seconds between two fights without footwork.
const FIGHT_SECONDS := 6.0
## Seconds the hero rests after losing a fight.
const REST_SECONDS := 20.0
## Turns after which a fight nobody wins counts as lost.
const MAX_TURNS := 40
## How much harder a critical strike hits.
const CRIT_DAMAGE := 2.0
const MAX_CRIT := 0.75
## The encouragement the player gives with a pat: cultivation is faster for
## `PAT_SECONDS`, and the next pat helps after `PAT_COOLDOWN`.
const PAT_BOOST := 2.0
const PAT_SECONDS := 60.0
const PAT_COOLDOWN := 300.0
## Time away counted when the game comes back, at most.
const MAX_AWAY_SECONDS := 12.0 * 3600.0

static func stage_of(realm: int, layer: int) -> int:
	return realm * LAYERS + layer - 1

## Cultivation the layer after `stage` costs.
static func layer_cost(stage: int) -> float:
	return LAYER_COST_BASE * pow(LAYER_COST_GROWTH, stage)

## Cultivation per second at `stage` with a bonus of `bonus` (0.2 is +20%).
static func qi_rate(stage: int, bonus: float) -> float:
	return pow(QI_RATE_GROWTH, stage) * (1.0 + bonus)

## Seconds between fights with a footwork bonus.
static func fight_seconds(speed_bonus: float) -> float:
	return FIGHT_SECONDS / (1.0 + speed_bonus)

## The hero's fight numbers: attack, health and crit chance.
static func hero_stats(stage: int, bonuses: Dictionary) -> Dictionary:
	var power := pow(POWER_GROWTH, stage)
	return {
		"attack": HERO_ATTACK * power * (1.0 + float(bonuses.get(JianghuArtData.Effect.ATTACK, 0.0))),
		"health": HERO_HEALTH * power * (1.0 + float(bonuses.get(JianghuArtData.Effect.HEALTH, 0.0))),
		"crit": minf(float(bonuses.get(JianghuArtData.Effect.CRIT, 0.0)), MAX_CRIT),
	}

## A foe's level in region `region` after `won` fights there; the boss when
## `won` reached `REGION_FIGHTS`.
static func foe_level(region: int, won: int) -> float:
	if won >= REGION_FIGHTS:
		return region * LAYERS + BOSS_LEVEL
	return region * LAYERS + won * FOE_LEVEL_PER_FIGHT

## A foe's fight numbers at `level`, scaled by its data; `boss` adds the
## boss's extra health and attack.
static func foe_stats(foe: JianghuFoeData, level: float, boss: bool) -> Dictionary:
	var power := pow(FOE_GROWTH, level)
	var attack := FOE_ATTACK * power * foe.attack_scale
	var health := FOE_HEALTH * power * foe.health_scale
	var silver := SILVER_BASE * pow(SILVER_GROWTH, level) * foe.silver_scale
	if boss:
		attack *= BOSS_ATTACK
		health *= BOSS_HEALTH
		silver *= BOSS_SILVER
	return {"attack": attack, "health": health, "silver": silver}

## How a fight goes: the hero strikes first, each of their blows hits for
## their attack (twice that on a crit, rolled with `roll`, a value in [0, 1)
## for each blow), the foe's for theirs. Returns whether the hero won and in
## how many turns.
static func fight(hero: Dictionary, foe: Dictionary, roll: Callable) -> Dictionary:
	var foe_health := float(foe.health)
	var hero_health := float(hero.health)
	for turn: int in range(1, MAX_TURNS + 1):
		var blow := float(hero.attack)
		if float(roll.call()) < float(hero.crit):
			blow *= CRIT_DAMAGE
		foe_health -= blow
		if foe_health <= 0.0:
			return {"won": true, "turns": turn}
		hero_health -= float(foe.attack)
		if hero_health <= 0.0:
			return {"won": false, "turns": turn}
	return {"won": false, "turns": MAX_TURNS}
