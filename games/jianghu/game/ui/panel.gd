class_name JianghuPanel
extends PanelContainer

## The hero's scroll: the realm and layer with the cultivation towards the
## next, the rates, the step into the next realm when it is due, a pat to
## spur the hero on, and three pages: martial arts, the roaming, and options.

signal close_requested
signal settings_requested
## The player patted the hero from the panel.
signal pat_requested

const WIDTH := 336.0
const PAGE_HEIGHT := 210.0

var desk_window: JianghuDeskWindow:
	set(value):
		desk_window = value
		if _options != null:
			_options.desk_window = value

var _seal: JianghuSealIcon
var _realm: Label
var _layer: Label
var _bar: ProgressBar
var _rates: Label
var _break: Button
var _gate: Label
var _pat: Button
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _options: JianghuOptionsPage

func _ready() -> void:
	theme = JianghuStyle.make_theme()
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	layout.add_child(_header())
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.show_percentage = false
	layout.add_child(_bar)
	_rates = JianghuStyle.label("", 12, JianghuStyle.INK_SOFT)
	layout.add_child(_rates)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	_break = Button.new()
	_break.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_break.pressed.connect(_on_break_through)
	_pat = Button.new()
	_pat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pat.pressed.connect(pat_requested.emit)
	actions.add_child(_break)
	actions.add_child(_pat)
	layout.add_child(actions)
	_gate = JianghuStyle.label("", 11, JianghuStyle.SEAL)
	_gate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_gate)
	layout.add_child(_tab_row())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, PAGE_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	layout.add_child(scroll)
	var arts := JianghuArtsPage.new()
	var roam := JianghuRoamPage.new()
	_options = JianghuOptionsPage.new()
	_options.desk_window = desk_window
	_options.settings_requested.connect(settings_requested.emit)
	for page: Control in [arts, roam, _options]:
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pages.add_child(page)
		_pages.append(page)
	show_page(0)
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)
	Cultivation.changed.connect(refresh)
	GameSettings.locale_changed.connect(func(_locale: String) -> void: _retitle())
	refresh()

func show_page(index: int) -> void:
	for i: int in _pages.size():
		_pages[i].visible = i == index
		_tabs[i].set_pressed_no_signal(i == index)
	(_pages[index] as Variant).refresh()

func refresh() -> void:
	var realm := Cultivation.get_realm_data()
	if realm == null:
		return
	_seal.color = JianghuStyle.SEAL
	_seal.character = tr(realm.display_name).left(1)
	_realm.text = tr(realm.display_name)
	_layer.text = tr("Layer %d of %d") % [Cultivation.layer, JianghuRules.LAYERS]
	var cost := Cultivation.get_layer_cost()
	_bar.max_value = cost
	_bar.value = minf(Cultivation.qi, cost)
	_rates.text = tr("Cultivation %s/%s (+%s/s)   Silver %s") % [
		JianghuNumbers.format(Cultivation.qi), JianghuNumbers.format(cost),
		JianghuNumbers.format_rate(Cultivation.get_qi_rate()), JianghuNumbers.format(Cultivation.silver)]
	_break.visible = Cultivation.layer >= JianghuRules.LAYERS and not Cultivation.is_last_realm()
	_break.disabled = not Cultivation.can_break_through()
	_break.text = tr("Break through")
	_gate.visible = _break.visible and Cultivation.is_gate_closed()
	if _gate.visible:
		var gate := JianghuRegionData.find(realm.gate_region_id)
		var boss := JianghuFoeData.find(gate.boss_id) if gate != null else null
		_gate.text = tr("To break through, first defeat %s in %s.") % [tr(boss.display_name) if boss else "", tr(gate.display_name) if gate else ""]
	if Cultivation.is_boosted():
		_pat.text = tr("Inspired %s") % JianghuNumbers.format_duration(Cultivation.get_boost_left())
		_pat.disabled = true
	elif not Cultivation.can_pat():
		_pat.text = tr("Pat again in %s") % JianghuNumbers.format_duration(Cultivation.get_pat_wait())
		_pat.disabled = true
	else:
		_pat.text = tr("Pat (cultivation ×2)")
		_pat.disabled = false
	for page: Control in _pages:
		if page.visible:
			(page as Variant).refresh()

func _header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_seal = JianghuSealIcon.new("", JianghuStyle.SEAL, 40.0)
	header.add_child(_seal)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	_realm = JianghuStyle.label("", 18)
	_layer = JianghuStyle.label("", 12, JianghuStyle.INK_SOFT)
	names.add_child(_realm)
	names.add_child(_layer)
	header.add_child(names)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(30, 30)
	close.pressed.connect(close_requested.emit)
	header.add_child(close)
	return header

func _tab_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for i: int in 3:
		var tab := Button.new()
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		JianghuStyle.style_tab(tab)
		tab.pressed.connect(show_page.bind(i))
		row.add_child(tab)
		_tabs.append(tab)
	_retitle()
	return row

func _retitle() -> void:
	if _tabs.size() < 3:
		return
	_tabs[0].text = tr("Martial arts")
	_tabs[1].text = tr("Roaming")
	_tabs[2].text = tr("Settings")

func _on_break_through() -> void:
	Cultivation.break_through()
