class_name JianghuRoamPage
extends VBoxContainer

## Where the hero roams: the region and how far along it they are, the next
## foe beside the hero's own numbers, the latest fights, and the road of
## regions with those already beaten.

var _region: Label
var _progress: Label
var _versus: Label
var _status: Label
var _log: Label
var _road: Label

func _ready() -> void:
	add_theme_constant_override("separation", 5)
	_region = JianghuStyle.label("", 15)
	_progress = JianghuStyle.label("", 12, JianghuStyle.INK_SOFT)
	_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_versus = JianghuStyle.label("", 12)
	_versus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = JianghuStyle.label("", 12, JianghuStyle.SEAL)
	_log = JianghuStyle.label("", 11, JianghuStyle.INK_SOFT)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_road = JianghuStyle.label("", 11, JianghuStyle.INK_SOFT)
	_road.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for node: Control in [_region, _progress, _versus, _status, JianghuStyle.label(tr("Latest fights"), 12), _log, JianghuStyle.label(tr("The road"), 12), _road]:
		add_child(node)
	Cultivation.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_visible_in_tree():
		return
	var region := Cultivation.get_region_data()
	if region == null:
		return
	_region.text = tr(region.display_name)
	var boss := JianghuFoeData.find(region.boss_id)
	if Cultivation.won >= JianghuRules.REGION_FIGHTS:
		_progress.text = tr(region.description) + "\n" + tr("The boss %s bars the way.") % (tr(boss.display_name) if boss else "")
	else:
		_progress.text = tr(region.description) + "\n" + tr("Foes beaten %d/%d, then the boss.") % [Cultivation.won, JianghuRules.REGION_FIGHTS]
	var hero := Cultivation.get_hero_stats()
	var foe_id: StringName = region.boss_id if Cultivation.won >= JianghuRules.REGION_FIGHTS else region.foe_ids[Cultivation.won % region.foe_ids.size()]
	var foe := JianghuFoeData.find(foe_id)
	if foe != null:
		var stats := JianghuRules.foe_stats(foe, JianghuRules.foe_level(Cultivation.region, Cultivation.won), Cultivation.won >= JianghuRules.REGION_FIGHTS)
		_versus.text = tr("Hero: attack %s · health %s · double blow %d%%") % [
			JianghuNumbers.format(hero.attack), JianghuNumbers.format(hero.health), roundi(float(hero.crit) * 100.0)] \
			+ "\n" + tr("Next: %s · attack %s · health %s") % [
			tr(foe.display_name), JianghuNumbers.format(stats.attack), JianghuNumbers.format(stats.health)]
	if Cultivation.rest > 0.0:
		_status.text = tr("Resting from wounds: %s") % JianghuNumbers.format_duration(Cultivation.rest)
	else:
		_status.text = tr("Next fight in %s") % JianghuNumbers.format_duration(Cultivation.get_fight_seconds() - Cultivation.fight_clock + 0.99)
	var lines := PackedStringArray()
	for i: int in range(Cultivation.fight_log.size() - 1, -1, -1):
		lines.append(fight_line(Cultivation.fight_log[i]))
	_log.text = "\n".join(lines) if not lines.is_empty() else tr("No fights yet.")
	var road := PackedStringArray()
	for data: JianghuRegionData in JianghuRegionData.find_all():
		var mark := "●" if Cultivation.cleared > data.order else ("◎" if data.order == Cultivation.region else "○")
		road.append("%s %s" % [mark, tr(data.display_name)])
	_road.text = "  ".join(road)

## One fight as the log tells it.
static func fight_line(entry: Dictionary) -> String:
	var foe := JianghuFoeData.find(StringName(String(entry.get("foe", ""))))
	var foe_name: String = TranslationServer.translate(foe.display_name) if foe != null else "?"
	if bool(entry.get("won", false)):
		return String(TranslationServer.translate("Beat %s, +%s silver")) % [foe_name, JianghuNumbers.format(float(entry.get("silver", 0.0)))]
	return String(TranslationServer.translate("Lost to %s")) % foe_name
