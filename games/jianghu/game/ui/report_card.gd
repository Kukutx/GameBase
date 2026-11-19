class_name JianghuReportCard
extends PanelContainer

## A card over everything: what the hero did while the player was away, or
## the crowning as first under heaven.

signal closed

var _title: Label
var _body: Label

func _ready() -> void:
	theme = JianghuStyle.make_theme()
	custom_minimum_size = Vector2(290, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	_title = JianghuStyle.label("", 20, JianghuStyle.SEAL)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body = JianghuStyle.label("", 13)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(266, 0)
	var ok := Button.new()
	ok.text = tr("Good")
	ok.pressed.connect(_close)
	layout.add_child(_title)
	layout.add_child(_body)
	layout.add_child(ok)

## Shows what `report` (from `Cultivation.take_away_report()`) tells.
func show_away(report: Dictionary) -> void:
	_title.text = tr("Back from seclusion")
	_body.text = away_text(report)
	_open()

func show_champion() -> void:
	_title.text = tr("First under heaven")
	_body.text = tr("The Leader of the Martial Alliance has fallen. All the jianghu now knows your little hero's name. The road goes on: keep training, and the assembly will keep testing you.")
	_open()

static func away_text(report: Dictionary) -> String:
	var text := String(TranslationServer.translate("You were away %s. Your hero cultivated %s qi and climbed %d layers, won %d fights (lost %d) and earned %s silver.")) % [
		JianghuNumbers.format_duration(float(report.get("seconds", 0.0))), JianghuNumbers.format(float(report.get("qi", 0.0))),
		int(report.get("layers", 0.0)), int(report.get("wins", 0.0)), int(report.get("losses", 0.0)),
		JianghuNumbers.format(float(report.get("silver", 0.0)))]
	if float(report.get("bosses", 0.0)) > 0.0:
		text += "\n" + String(TranslationServer.translate("Bosses defeated: %d!")) % int(report.bosses)
	return text

func _open() -> void:
	visible = true
	reset_size()

func _close() -> void:
	visible = false
	closed.emit()
