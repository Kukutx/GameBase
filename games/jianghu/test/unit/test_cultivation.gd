extends GutTest

## Pocket Jianghu's rules and the hero's progress: the numbers, a fight, the
## layers filling, the gate of a realm, martial arts, the pat, the time away
## and the state the world keeps.

var _world: Dictionary
var _now := 1000000.0

func before_each() -> void:
	_world = WorldState.to_save_data()
	WorldState.clear()
	Cultivation.clock = func() -> float: return _now

func after_each() -> void:
	Cultivation.clock = Time.get_unix_time_from_system
	WorldState.load_save_data(_world)

func test_numbers_read_in_the_units_of_the_language() -> void:
	assert_eq(JianghuNumbers.format(9999.0, "zh_CN"), "9999")
	assert_eq(JianghuNumbers.format(12500.0, "zh_CN"), "1.25万")
	assert_eq(JianghuNumbers.format(345000000.0, "zh_CN"), "3.45亿")
	assert_eq(JianghuNumbers.format(12500.0, "en"), "12.5K")
	assert_eq(JianghuNumbers.format(2.0e9, "en"), "2.00B")

func test_a_fresh_hero_starts_at_the_bottom() -> void:
	assert_eq(Cultivation.realm, 0)
	assert_eq(Cultivation.layer, 1)
	assert_eq(Cultivation.silver, 0.0)
	assert_eq(Cultivation.region, 0)

func test_cultivation_fills_the_layers_of_a_realm_but_not_the_next() -> void:
	Cultivation.advance(100000.0)
	assert_eq(Cultivation.layer, JianghuRules.LAYERS, "layers come on their own")
	assert_eq(Cultivation.realm, 0, "the next realm waits for the player")
	assert_true(Cultivation.is_at_peak())
	assert_true(Cultivation.is_gate_closed() or Cultivation.cleared > 0)

func test_breaking_through_needs_the_gate_region_beaten() -> void:
	Cultivation.layer = JianghuRules.LAYERS
	Cultivation.qi = Cultivation.get_layer_cost()
	Cultivation.cleared = 0
	assert_false(Cultivation.break_through(), "the town's bully still stands")
	Cultivation.cleared = 1
	assert_true(Cultivation.break_through())
	assert_eq(Cultivation.realm, 1)
	assert_eq(Cultivation.layer, 1)
	assert_eq(Cultivation.qi, 0.0)

func test_a_strong_hero_wins_and_a_weak_one_rests() -> void:
	var foe := JianghuFoeData.find(&"thug")
	var weak := JianghuRules.fight({"attack": 1.0, "health": 1.0, "crit": 0.0}, JianghuRules.foe_stats(foe, 0.0, false), func() -> float: return 0.5)
	assert_false(bool(weak.won))
	var strong := JianghuRules.fight({"attack": 1000.0, "health": 1000.0, "crit": 0.0}, JianghuRules.foe_stats(foe, 0.0, false), func() -> float: return 0.5)
	assert_true(bool(strong.won))
	assert_eq(int(strong.turns), 1)

func test_roaming_wins_silver_and_reaches_the_boss() -> void:
	Cultivation.realm = 1
	Cultivation.layer = 1
	var report := {}
	Cultivation.advance(JianghuRules.FIGHT_SECONDS * 12.0, report)
	assert_gt(Cultivation.silver, 0.0, "fights pay silver")
	assert_gt(float(report.get("wins", 0.0)), 0.0)
	assert_gt(Cultivation.cleared, 0, "the town's bully falls to a hero of the next realm")
	assert_eq(Cultivation.region, 1, "the road leads on")

func test_studying_an_art_costs_silver_and_raises_its_bonus() -> void:
	var art := JianghuArtData.find(&"breathing")
	assert_false(Cultivation.study(art.id), "no silver yet")
	Cultivation.silver = art.cost_at(0)
	var rate := Cultivation.get_qi_rate()
	assert_true(Cultivation.study(art.id))
	assert_eq(Cultivation.get_art_level(art.id), 1)
	assert_almost_eq(Cultivation.silver, 0.0, 0.001)
	assert_almost_eq(Cultivation.get_qi_rate(), rate * (1.0 + art.per_level), 0.0001)
	assert_eq(Cultivation.get_study_block(JianghuArtData.find(&"cloud_sword")), "realm", "a later art waits for its realm")

func test_a_pat_doubles_cultivation_for_a_while() -> void:
	var rate := Cultivation.get_qi_rate()
	assert_true(Cultivation.pat())
	assert_almost_eq(Cultivation.get_qi_rate(), rate * JianghuRules.PAT_BOOST, 0.0001)
	assert_false(Cultivation.pat(), "the next pat waits")
	_now += JianghuRules.PAT_SECONDS + 1.0
	assert_almost_eq(Cultivation.get_qi_rate(), rate, 0.0001)
	_now += JianghuRules.PAT_COOLDOWN
	assert_true(Cultivation.can_pat())

func test_time_away_is_played_out_and_reported() -> void:
	var report := Cultivation.play_out(3600.0)
	assert_eq(float(report.seconds), 3600.0)
	assert_gt(float(report.get("qi", 0.0)), 0.0)
	assert_gt(float(report.get("layers", 0.0)), 0.0)
	assert_gt(float(report.get("wins", 0.0)), 0.0)
	assert_false(Cultivation.is_playing_out())

func test_the_hero_is_kept_in_the_world_and_read_back() -> void:
	Cultivation.realm = 2
	Cultivation.layer = 4
	Cultivation.silver = 1234.5
	Cultivation.arts[&"long_fist"] = 3
	Cultivation.region = 2
	Cultivation.won = 5
	Cultivation.cleared = 2
	Cultivation.pat()
	var saved := JSON.parse_string(JSON.stringify(WorldState.to_save_data())) as Dictionary
	WorldState.clear()
	assert_eq(Cultivation.realm, 0, "a cleared world is a fresh hero")
	WorldState.load_save_data(saved)
	assert_eq(Cultivation.realm, 2)
	assert_eq(Cultivation.layer, 4)
	assert_almost_eq(Cultivation.silver, 1234.5, 0.001)
	assert_eq(Cultivation.get_art_level(&"long_fist"), 3)
	assert_eq(Cultivation.region, 2)
	assert_eq(Cultivation.won, 5)
	assert_eq(Cultivation.cleared, 2)
	assert_true(Cultivation.is_boosted())

func test_a_broken_save_reads_as_a_sane_hero() -> void:
	WorldState.set_value(Cultivation.STATE_KEY, {"realm": 99, "layer": -3, "qi": "lots", "arts": {"nonsense": 5, "breathing": 999}, "region": 1.5})
	WorldState.load_save_data(JSON.parse_string(JSON.stringify(WorldState.to_save_data())) as Dictionary)
	assert_eq(Cultivation.realm, JianghuRealmData.find_all().size() - 1)
	assert_eq(Cultivation.layer, 1)
	assert_eq(Cultivation.qi, 0.0)
	assert_false(Cultivation.arts.has(&"nonsense"))
	assert_eq(Cultivation.get_art_level(&"breathing"), JianghuArtData.find(&"breathing").max_level)
	assert_eq(Cultivation.region, 0)
