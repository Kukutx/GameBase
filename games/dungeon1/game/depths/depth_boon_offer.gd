class_name DepthBoonOffer
extends ShopOffer

## A boon for the run (`BoonData`) the Ember Peddler sells, once a depth, at
## `price` coins: which one is the run's to roll for the depth
## (`RunState.offer_boons()`, from `pool`, never one of `excluded`), so the
## same depth of the same run sells the same, and none while no run goes on or
## once it sold its boon.

## What the boon costs.
@export_range(1, 9999, 1) var price := 60
## The pool the boon comes from (`BoonData.pool`); empty, the common one.
@export var pool: StringName
## Boons it never sells, such as one that only finds coins.
@export var excluded: Array[StringName] = []

func get_key() -> String:
	return "depth_boon"

## The boon on sale at this depth of the run, or null when there is none.
func get_boon() -> BoonData:
	if not RunState.is_active():
		return null
	for boon: BoonData in RunState.offer_boons(1 + excluded.size(), "peddler%d" % DepthRun.get_depth(), pool):
		if not excluded.has(boon.id):
			return boon
	return null

## Whether the peddler of this depth of the run sold its boon.
func is_sold() -> bool:
	return bool(RunState.get_value(_sold_key(), false))

func get_label(_context: Dictionary) -> String:
	var boon := get_boon()
	if boon == null or is_sold():
		return tr("No boon for sale")
	return tr("Boon: %s — %dg") % [tr(boon.display_name), price]

func can_buy(_context: Dictionary) -> bool:
	return get_boon() != null and not is_sold() and Wallet.can_afford(price)

func buy(_context: Dictionary) -> bool:
	if not can_buy(_context) or not RunState.take_boon(get_boon().id):
		return false
	Wallet.spend(price)
	RunState.set_value(_sold_key(), true)
	return true

## What is wrong with the offer: a boon it never sells that does not exist,
## or a pool that holds none it sells.
func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for boon_id: StringName in excluded:
		if registry.get_entry(BoonData.KIND, boon_id) == null:
			problems.append("never sells unknown boon '%s'" % boon_id)
	var sells := registry.get_entries(BoonData.KIND).any(func(boon: BoonData) -> bool:
		return boon.pool == pool and not excluded.has(boon.id))
	if not sells:
		problems.append("sells a boon of pool '%s', which holds none it sells" % pool)
	return problems

func _sold_key() -> StringName:
	return StringName("peddler_sold:%d" % DepthRun.get_depth())
