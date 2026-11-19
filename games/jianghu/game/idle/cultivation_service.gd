class_name JianghuCultivation
extends Node

## The hero's progress (`Cultivation`): cultivation that climbs the layers of
## each realm, silver won while roaming that buys martial arts, and the
## regions of the jianghu beaten in order. Everything advances with time, in
## the window or not: when play starts again the time away (at most
## `JianghuRules.MAX_AWAY_SECONDS`) is played out in steps and summed up for
## the player (`take_away_report()`).
##
## The layers inside a realm come on their own as cultivation fills them; the
## step into the next realm is the player's (`break_through()`) once the last
## layer is full and the realm's gate region is beaten.
##
## Everything persists in `WorldState` under `STATE_KEY`, so it saves with the
## world, and a new game, which clears the world, starts the hero afresh.

signal changed
## A new layer or realm was reached.
signal advanced(realm: int, layer: int, new_realm: bool)
## A fight ended: `report` holds foe (id), boss, won and silver.
signal fought(report: Dictionary)
signal art_learned(art_id: StringName, level: int)
## The last region's boss fell for the first time.
signal champion_crowned

const STATE_KEY := &"jianghu:hero"
## Seconds of a step when the time away is played out.
const AWAY_STEP := 30.0
## Time away shorter than this is not reported.
const AWAY_REPORT_MIN := 60.0
const LOG_SIZE := 6
const SAVE_EVERY := 1.0

var realm := 0
var layer := 1
## Cultivation towards the next layer.
var qi := 0.0
var silver := 0.0
var arts: Dictionary[StringName, int] = {}
## The region the hero roams (its order) and the fights won there since its boss.
var region := 0
var won := 0
## How many regions have had their boss beaten, in order.
var cleared := 0
var champion := false
var wins := 0
var losses := 0
## Seconds since the last fight, and of rest left after a lost one.
var fight_clock := 0.0
var rest := 0.0
## Unix times: until when a pat speeds cultivation, and when the next may.
var boost_until := 0.0
var pat_ready_at := 0.0
## The latest fights, newest last.
var fight_log: Array[Dictionary] = []
## Returns the time now in Unix seconds; tests replace it.
var clock: Callable = Time.get_unix_time_from_system

var _last_seen := 0.0
var _active := false
var _loading := false
var _since_save := 0.0
var _away_report: Dictionary = {}
var _fight_count := 0
var _playing_out := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	WorldState.changed.connect(_on_world_changed)
	GameSession.play_started.connect(_on_play_started)
	_load()

func _process(delta: float) -> void:
	if not _active:
		return
	advance(delta)
	_since_save += delta
	if _since_save >= SAVE_EVERY:
		_save()

func get_stage() -> int:
	return JianghuRules.stage_of(realm, layer)

func get_realm_data() -> JianghuRealmData:
	var realms := JianghuRealmData.find_all()
	return realms[clampi(realm, 0, realms.size() - 1)] if not realms.is_empty() else null

func get_region_data() -> JianghuRegionData:
	var regions := JianghuRegionData.find_all()
	return regions[clampi(region, 0, regions.size() - 1)] if not regions.is_empty() else null

func get_layer_cost() -> float:
	return JianghuRules.layer_cost(get_stage())

## The sum of what the arts learnt give, by `JianghuArtData.Effect`.
func get_bonuses() -> Dictionary:
	var bonuses := {}
	for art: JianghuArtData in JianghuArtData.find_all():
		var level := int(arts.get(art.id, 0))
		if level > 0:
			bonuses[art.effect] = float(bonuses.get(art.effect, 0.0)) + art.per_level * level
	return bonuses

func is_boosted() -> bool:
	return clock.call() < boost_until

func get_qi_rate() -> float:
	var rate := JianghuRules.qi_rate(get_stage(), float(get_bonuses().get(JianghuArtData.Effect.QI_RATE, 0.0)))
	return rate * JianghuRules.PAT_BOOST if is_boosted() else rate

func get_hero_stats() -> Dictionary:
	return JianghuRules.hero_stats(get_stage(), get_bonuses())

func get_fight_seconds() -> float:
	return JianghuRules.fight_seconds(float(get_bonuses().get(JianghuArtData.Effect.SPEED, 0.0)))

## Whether the last layer of the realm is full.
func is_at_peak() -> bool:
	return layer >= JianghuRules.LAYERS and qi >= get_layer_cost()

func is_last_realm() -> bool:
	return realm >= JianghuRealmData.find_all().size() - 1

## Whether the realm's gate region still stands in the way.
func is_gate_closed() -> bool:
	var data := get_realm_data()
	if data == null or data.gate_region_id == &"":
		return false
	var gate := JianghuRegionData.find(data.gate_region_id)
	return gate != null and cleared <= gate.order

func can_break_through() -> bool:
	return is_at_peak() and not is_last_realm() and not is_gate_closed()

## Steps into the next realm; false, changing nothing, when it cannot.
func break_through() -> bool:
	if not can_break_through():
		return false
	qi = 0.0
	realm += 1
	layer = 1
	advanced.emit(realm, layer, true)
	_commit()
	return true

func get_art_level(art_id: StringName) -> int:
	return int(arts.get(art_id, 0))

## Why the art cannot be studied now, or "" when it can.
func get_study_block(art: JianghuArtData) -> String:
	if realm < art.unlock_realm:
		return "realm"
	if get_art_level(art.id) >= art.max_level:
		return "max"
	if silver < art.cost_at(get_art_level(art.id)):
		return "silver"
	return ""

func study(art_id: StringName) -> bool:
	var art := JianghuArtData.find(art_id)
	if art == null or not get_study_block(art).is_empty():
		return false
	var level := get_art_level(art_id)
	silver -= art.cost_at(level)
	arts[art_id] = level + 1
	art_learned.emit(art_id, level + 1)
	_commit()
	return true

## Whether a pat would encourage the hero now.
func can_pat() -> bool:
	return clock.call() >= pat_ready_at

func get_pat_wait() -> float:
	return maxf(pat_ready_at - float(clock.call()), 0.0)

func get_boost_left() -> float:
	return maxf(boost_until - float(clock.call()), 0.0)

## The player pats the hero: faster cultivation for a while. False while the
## last pat still cools down.
func pat() -> bool:
	var now := float(clock.call())
	if now < pat_ready_at:
		return false
	boost_until = now + JianghuRules.PAT_SECONDS
	pat_ready_at = now + JianghuRules.PAT_COOLDOWN
	_commit()
	return true

## Plays out `seconds`: cultivation fills the layers, fights come at their pace.
## `report`, when given, sums what happened.
func advance(seconds: float, report: Dictionary = {}) -> void:
	var left := seconds
	# Cultivation in pieces, so each layer reached speeds up the rest.
	while left > 0.0:
		var rate := get_qi_rate()
		var cost := get_layer_cost()
		if layer >= JianghuRules.LAYERS or qi + rate * left < cost:
			qi += rate * left
			_add(report, "qi", rate * left)
			break
		var needed := maxf((cost - qi) / rate, 0.0)
		_add(report, "qi", cost - qi)
		left -= needed
		qi = 0.0
		layer += 1
		_add(report, "layers", 1)
		advanced.emit(realm, layer, false)
	_advance_fights(seconds, report)
	changed.emit()

## Takes the summary of the time away once, empty when there was none to tell.
func take_away_report() -> Dictionary:
	var report := _away_report
	_away_report = {}
	return report

func _advance_fights(seconds: float, report: Dictionary) -> void:
	var time := seconds
	if rest > 0.0:
		var rested := minf(rest, time)
		rest -= rested
		time -= rested
		if rest > 0.0:
			return
	fight_clock += time
	var interval := get_fight_seconds()
	while fight_clock >= interval:
		fight_clock -= interval
		if not _fight(report):
			rest = JianghuRules.REST_SECONDS
			fight_clock = 0.0
			return

func _fight(report: Dictionary) -> bool:
	var data := get_region_data()
	if data == null:
		return true
	var boss := won >= JianghuRules.REGION_FIGHTS
	var foe_id := data.boss_id if boss else data.foe_ids[won % data.foe_ids.size()]
	var foe := JianghuFoeData.find(foe_id)
	if foe == null:
		return true
	var stats := JianghuRules.foe_stats(foe, JianghuRules.foe_level(region, won), boss)
	_fight_count += 1
	var stream := GameRandom.stream("jianghu:fight:%d:%d:%d" % [region, won, _fight_count])
	var result := JianghuRules.fight(get_hero_stats(), stats, stream.randf)
	var entry := {"foe": String(foe_id), "boss": boss, "won": bool(result.won), "silver": 0.0}
	if result.won:
		var reward := float(stats.silver) * (1.0 + float(get_bonuses().get(JianghuArtData.Effect.SILVER, 0.0)))
		silver += reward
		entry.silver = reward
		wins += 1
		_add(report, "wins", 1)
		_add(report, "silver", reward)
		if boss:
			_beat_boss(report)
		else:
			won += 1
	else:
		losses += 1
		_add(report, "losses", 1)
	fight_log.append(entry)
	while fight_log.size() > LOG_SIZE:
		fight_log.pop_front()
	fought.emit(entry)
	return bool(result.won)

func _beat_boss(report: Dictionary) -> void:
	_add(report, "bosses", 1)
	won = 0
	cleared = maxi(cleared, region + 1)
	var last := JianghuRegionData.find_all().size() - 1
	if region < last:
		region += 1
	elif not champion:
		champion = true
		champion_crowned.emit()

static func _add(report: Dictionary, key: String, amount: float) -> void:
	report[key] = float(report.get(key, 0.0)) + amount

func _on_play_started() -> void:
	_active = true
	var now := float(clock.call())
	var away := clampf(now - _last_seen, 0.0, JianghuRules.MAX_AWAY_SECONDS) if _last_seen > 0.0 else 0.0
	if away >= AWAY_REPORT_MIN:
		_away_report = play_out(away)
	_commit()

## Plays out `seconds` away in steps and returns what happened, with the
## seconds counted.
func play_out(seconds: float) -> Dictionary:
	var report := {"seconds": seconds}
	var left := seconds
	_playing_out = true
	while left > 0.0:
		var step := minf(left, AWAY_STEP)
		advance(step, report)
		left -= step
	_playing_out = false
	return report

## Whether the time away is being played out now: what happens then is told
## in the summary, not one by one.
func is_playing_out() -> bool:
	return _playing_out

func _commit() -> void:
	changed.emit()
	_save()

func _save() -> void:
	if _loading:
		return
	_since_save = 0.0
	_last_seen = float(clock.call())
	var learnt := {}
	for art_id: StringName in arts:
		learnt[String(art_id)] = arts[art_id]
	WorldState.set_value(STATE_KEY, {
		"realm": realm, "layer": layer, "qi": qi, "silver": silver, "arts": learnt,
		"region": region, "won": won, "cleared": cleared, "champion": champion,
		"wins": wins, "losses": losses, "fight_clock": fight_clock, "rest": rest,
		"boost_until": boost_until, "pat_ready_at": pat_ready_at, "last_seen": _last_seen,
	})

func _on_world_changed(key: StringName, _value: Variant) -> void:
	if key == &"":
		_load()

# Reads the hero back from the world: a fresh hero when it holds none, and
# values clamped to what the current content allows.
func _load() -> void:
	_loading = true
	var data: Variant = WorldState.get_value(STATE_KEY, {})
	var saved: Dictionary = data if data is Dictionary else {}
	var realm_count := maxi(JianghuRealmData.find_all().size(), 1)
	var region_count := maxi(JianghuRegionData.find_all().size(), 1)
	realm = clampi(SaveValues.count(saved.get("realm")), 0, realm_count - 1)
	layer = clampi(SaveValues.whole_number_or(saved.get("layer"), 1), 1, JianghuRules.LAYERS)
	qi = _number(saved.get("qi"))
	silver = _number(saved.get("silver"))
	arts.clear()
	var learnt: Variant = saved.get("arts", {})
	if learnt is Dictionary:
		for key: Variant in learnt:
			var art := JianghuArtData.find(StringName(String(key)))
			if art != null:
				arts[art.id] = clampi(SaveValues.count(learnt[key]), 0, art.max_level)
	region = clampi(SaveValues.count(saved.get("region")), 0, region_count - 1)
	won = clampi(SaveValues.count(saved.get("won")), 0, JianghuRules.REGION_FIGHTS)
	cleared = clampi(SaveValues.count(saved.get("cleared")), 0, region_count)
	champion = bool(saved.get("champion", false))
	wins = SaveValues.count(saved.get("wins"))
	losses = SaveValues.count(saved.get("losses"))
	fight_clock = _number(saved.get("fight_clock"))
	rest = _number(saved.get("rest"))
	boost_until = _number(saved.get("boost_until"))
	pat_ready_at = _number(saved.get("pat_ready_at"))
	_last_seen = _number(saved.get("last_seen"))
	fight_log.clear()
	_away_report = {}
	_active = false
	_loading = false
	changed.emit()

static func _number(value: Variant) -> float:
	if value is float or value is int:
		var number := float(value)
		if not is_nan(number) and not is_inf(number) and number >= 0.0:
			return number
	return 0.0
