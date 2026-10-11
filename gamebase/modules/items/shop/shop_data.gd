class_name ShopData
extends ContentEntry

const KIND := &"shop"

@export var display_name: String = "Shop"
@export var stock: Dictionary = {}
@export var seasonal_stock: Dictionary = {}
## What the shop sells besides items, after them (see `ShopOffer`).
@export var offers: Array[ShopOffer] = []

## The shop with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> ShopData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as ShopData

## The running game's shops, sorted by id.
static func find_all() -> Array[ShopData]:
	var result: Array[ShopData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func get_stock(season_name: String = "") -> Dictionary:
	var resolved_season := WorldClock.get_season_name() if season_name.is_empty() else season_name
	var result := stock.duplicate(true)
	var seasonal: Variant = seasonal_stock.get(resolved_season, {})
	if seasonal is Dictionary:
		for raw_id: Variant in seasonal.keys():
			result[String(raw_id)] = seasonal[raw_id]
	return result

func get_buy_price(item: ItemData) -> int:
	if item == null:
		return 0
	var raw_price: Variant = get_stock().get(String(item.id), item.buy_price)
	if typeof(raw_price) != TYPE_INT and typeof(raw_price) != TYPE_FLOAT:
		return 0
	return maxi(int(raw_price), 0)

func has_item(item_id: StringName) -> bool:
	return get_stock().has(String(item_id))

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has an empty display name")
	problems.append_array(ItemData.find_amount_problems(stock, registry, "stocks", "price"))
	for raw_season: Variant in seasonal_stock:
		var season := String(raw_season)
		var seasonal: Variant = seasonal_stock[raw_season]
		if not GameCalendar.current().has_season(season):
			problems.append("has unknown season '%s'" % season)
		elif not seasonal is Dictionary:
			problems.append("seasonal stock '%s' is not a Dictionary" % season)
		else:
			problems.append_array(ItemData.find_amount_problems(seasonal, registry, "stocks in %s" % season, "%s price" % season))
	var offer_keys: Dictionary = {}
	for offer: ShopOffer in offers:
		if offer == null:
			problems.append("has an empty offer")
			continue
		problems.append_array(offer.find_problems(registry))
		if offer_keys.has(offer.get_key()):
			problems.append("repeats offer '%s'" % offer.get_key())
		offer_keys[offer.get_key()] = true
	return problems
