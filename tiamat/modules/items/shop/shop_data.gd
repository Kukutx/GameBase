class_name ShopData
extends ContentEntry

## A shop: the items it sells and at what price, those it sells only in a
## season or while a condition holds (`ShopListing`), and its other offers
## (`ShopOffer`, an animal). A `ShopStand` in a
## scene opens its counter (`ShopMenu`); it buys every item that has a
## `sell_price`, and `ShopService` makes each trade.

const KIND := &"shop"

## The name the player reads at its counter.
@export var display_name: String = "Shop"
## What it sells all year, as item id -> price; 0, at the item's own
## `buy_price`, so a price every shop asks is set once, on the item.
@export var stock: Dictionary = {}
## What it sells besides in a season, as season name (`GameCalendar`) -> item
## id -> price (0, the item's own); a seasonal price takes the place of the
## year's.
@export var seasonal_stock: Dictionary = {}
## What it sells besides while a condition holds, each a `ShopListing` kept
## in the shop's file; an open listing's price takes the place of the stock's.
@export var listings: Array[ShopListing] = []
## How many of an item it sells a day, as item id -> count: what the player
## bought of it there that day counts (`ShopService.get_left_today()`), and a
## new day brings the full count back. An item it does not name sells without
## limit.
@export var daily_limits: Dictionary = {}
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
	for listing: ShopListing in listings:
		if listing != null and listing.is_open():
			result[String(listing.item_id)] = listing.price
	return result

## What the shop asks for one `item` now: its stock's price in this season, or
## the item's own `buy_price` where the stock gives 0 or does not list it.
func get_buy_price(item: ItemData) -> int:
	if item == null:
		return 0
	var raw_price: Variant = get_stock().get(String(item.id), 0)
	if typeof(raw_price) != TYPE_INT and typeof(raw_price) != TYPE_FLOAT:
		return 0
	var price := int(raw_price)
	return maxi(item.buy_price if price == 0 else price, 0)

func has_item(item_id: StringName) -> bool:
	return get_stock().has(String(item_id))

## How many of `item_id` the shop sells a day (`daily_limits`), or 0 for no
## limit.
func get_daily_limit(item_id: StringName) -> int:
	var limit: Variant = daily_limits.get(String(item_id), daily_limits.get(item_id, 0))
	return maxi(int(limit), 0) if typeof(limit) == TYPE_INT or typeof(limit) == TYPE_FLOAT else 0

## Whether the shop sells `item_id` in any season or while any of its
## listings is open.
func sells_ever(item_id: StringName) -> bool:
	if stock.has(String(item_id)) or stock.has(item_id):
		return true
	for seasonal: Variant in seasonal_stock.values():
		if seasonal is Dictionary and ((seasonal as Dictionary).has(String(item_id)) or (seasonal as Dictionary).has(item_id)):
			return true
	return listings.any(func(listing: ShopListing) -> bool: return listing != null and listing.item_id == item_id)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has an empty display name")
	problems.append_array(_find_price_problems(stock, registry, "stocks", "price"))
	for raw_season: Variant in seasonal_stock:
		var season := String(raw_season)
		var seasonal: Variant = seasonal_stock[raw_season]
		if not GameCalendar.current().has_season(season):
			problems.append("has unknown season '%s'" % season)
		elif not seasonal is Dictionary:
			problems.append("seasonal stock '%s' is not a Dictionary" % season)
		else:
			problems.append_array(_find_price_problems(seasonal, registry, "stocks in %s" % season, "%s price" % season))
	var listed: Dictionary = {}
	for listing: ShopListing in listings:
		if listing == null:
			problems.append("has an empty listing")
		elif listed.has(listing.item_id):
			problems.append("lists '%s' twice" % listing.item_id)
		else:
			listed[listing.item_id] = listing.price
	problems.append_array(_find_price_problems(listed, registry, "lists", "listing price"))
	for raw_id: Variant in daily_limits:
		var item_id := StringName(String(raw_id))
		var limit: Variant = daily_limits[raw_id]
		if registry.get_entry(ItemData.KIND, item_id) == null:
			problems.append("limits unknown item '%s'" % raw_id)
		elif typeof(limit) != TYPE_INT or int(limit) <= 0:
			problems.append("has an invalid daily limit for '%s'" % raw_id)
		elif not sells_ever(item_id):
			problems.append("limits '%s', which it never sells" % raw_id)
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

## Problems of `prices` (item id -> price) of the stock: an id that is no item
## of `registry`, a price that is not a whole number of 0 or more, or a 0 for an
## item with no `buy_price` of its own. `verb` says what the shop does with the
## items ("stocks in Spring"), `noun` what the prices are ("Spring price").
func _find_price_problems(prices: Dictionary, registry: ContentRegistry, verb: String, noun: String) -> PackedStringArray:
	var problems := PackedStringArray()
	for raw_id: Variant in prices:
		var item := registry.get_entry(ItemData.KIND, StringName(String(raw_id))) as ItemData
		var price: Variant = prices[raw_id]
		if item == null:
			problems.append("%s unknown item '%s'" % [verb, raw_id])
		elif typeof(price) != TYPE_INT or int(price) < 0:
			problems.append("has invalid %s for '%s'" % [noun, raw_id])
		elif int(price) == 0 and item.buy_price <= 0:
			problems.append("leaves the %s of '%s' to the item, which has no buy_price" % [noun, raw_id])
	return problems
