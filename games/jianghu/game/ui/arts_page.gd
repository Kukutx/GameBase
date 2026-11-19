class_name JianghuArtsPage
extends VBoxContainer

## The martial arts the hero can study: each with its seal, its level, what it
## gives now and at the next level, and a button that pays the silver.

var _rows: Dictionary[StringName, Dictionary] = {}

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	Cultivation.changed.connect(refresh)
	Cultivation.art_learned.connect(func(_id: StringName, _level: int) -> void: refresh())
	GameSettings.locale_changed.connect(func(_locale: String) -> void: _build())
	_build()

func _build() -> void:
	for child: Node in get_children():
		child.queue_free()
	_rows.clear()
	for art: JianghuArtData in JianghuArtData.find_all():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(JianghuSealIcon.new(art.seal))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		var title := JianghuStyle.label("", 14)
		var effect := JianghuStyle.label("", 11, JianghuStyle.INK_SOFT)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(title)
		text.add_child(effect)
		row.add_child(text)
		var button := Button.new()
		button.custom_minimum_size = Vector2(78, 34)
		button.add_theme_font_size_override("font_size", 11)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_study.bind(art.id))
		row.add_child(button)
		add_child(row)
		_rows[art.id] = {"title": title, "effect": effect, "button": button, "seal": row.get_child(0)}
	refresh()

func refresh() -> void:
	if not is_visible_in_tree():
		return
	for art: JianghuArtData in JianghuArtData.find_all():
		var row: Dictionary = _rows.get(art.id, {})
		if row.is_empty():
			continue
		var level := Cultivation.get_art_level(art.id)
		var block := Cultivation.get_study_block(art)
		(row.title as Label).text = tr("%s · level %d") % [tr(art.display_name), level]
		(row.effect as Label).text = "%s\n%s" % [tr(art.description), effect_text(art, level)]
		var button := row.button as Button
		var seal := row.seal as JianghuSealIcon
		seal.color = JianghuStyle.SEAL if block != "realm" else Color(0.6, 0.56, 0.52)
		match block:
			"realm":
				var realms := JianghuRealmData.find_all()
				var needed := realms[mini(art.unlock_realm, realms.size() - 1)]
				button.text = tr("Needs %s") % tr(needed.display_name)
				button.disabled = true
			"max":
				button.text = tr("Mastered")
				button.disabled = true
			_:
				button.text = tr("Study %s silver") % JianghuNumbers.format(art.cost_at(level))
				button.disabled = block == "silver"

## What the art gives at `level` and at the next one.
static func effect_text(art: JianghuArtData, level: int) -> String:
	var now := art.per_level * level * 100.0
	var next := art.per_level * mini(level + 1, art.max_level) * 100.0
	var template := ""
	match art.effect:
		JianghuArtData.Effect.QI_RATE:
			template = String(TranslationServer.translate("Cultivation +%d%% → +%d%%"))
		JianghuArtData.Effect.ATTACK:
			template = String(TranslationServer.translate("Attack +%d%% → +%d%%"))
		JianghuArtData.Effect.HEALTH:
			template = String(TranslationServer.translate("Vitality +%d%% → +%d%%"))
		JianghuArtData.Effect.SPEED:
			template = String(TranslationServer.translate("Fight pace +%d%% → +%d%%"))
		JianghuArtData.Effect.SILVER:
			template = String(TranslationServer.translate("Silver +%d%% → +%d%%"))
		JianghuArtData.Effect.CRIT:
			template = String(TranslationServer.translate("Double blow %d%% → %d%%"))
	return template % [roundi(now), roundi(next)]

func _on_study(art_id: StringName) -> void:
	if Cultivation.study(art_id):
		GameAudio.play_cue(&"sfx_study")
