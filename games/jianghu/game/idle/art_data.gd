class_name JianghuArtData
extends ContentEntry

## A martial art the hero can study with silver. Each level adds `per_level`
## to one of the hero's bonuses (`Effect`); the next level costs `base_cost`
## times `cost_growth` to the power of the levels already learnt.

enum Effect {
	## Cultivation gained per second.
	QI_RATE,
	## Attack in a fight.
	ATTACK,
	## Health in a fight.
	HEALTH,
	## How often the hero fights while roaming.
	SPEED,
	## Silver won from a fight.
	SILVER,
	## The chance of a critical strike, which hits twice as hard.
	CRIT,
}

const KIND := &"jianghu_art"

@export var display_name: String
@export var description: String
## The seal character drawn on the art's icon.
@export var seal: String
@export var effect: Effect = Effect.QI_RATE
@export var per_level := 0.1
@export var base_cost := 10.0
@export var cost_growth := 1.5
@export_range(1, 999) var max_level := 50
## The realm (`JianghuRealmData.order`) from which the art can be studied.
@export var unlock_realm := 0
## Where the art stands in the list.
@export var order := 0

static func find(entry_id: StringName) -> JianghuArtData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as JianghuArtData

## Every art, in `order`.
static func find_all() -> Array[JianghuArtData]:
	var result: Array[JianghuArtData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	result.sort_custom(func(a: JianghuArtData, b: JianghuArtData) -> bool: return a.order < b.order)
	return result

## Silver for the level after `level`.
func cost_at(level: int) -> float:
	return base_cost * pow(cost_growth, level)

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if seal.length() != 1:
		problems.append("needs a seal of one character")
	if base_cost <= 0.0 or cost_growth < 1.0 or per_level <= 0.0:
		problems.append("has a cost or effect that does not grow")
	return problems
