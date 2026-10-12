class_name InteractionController
extends Area2D

signal focus_changed(target: Interactable)

@export var action: StringName = &"interact"
@export var actor: Node
@export var prompt_label: Label

var _nearby: Array[Interactable] = []
var _focused: Interactable

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	InputPrompts.input_method_changed.connect(_on_prompt_context_changed)
	GameSettings.controls_changed.connect(_on_prompt_context_changed)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh_focus()

func _process(_delta: float) -> void:
	_refresh_focus()

func _unhandled_input(event: InputEvent) -> void:
	# While a dialogue, a fishing cast or a minigame holds the controls, the
	# press is theirs (a cast reels in with it).
	if not event.is_action_pressed(action) or InputLock.is_locked():
		return
	_refresh_focus()
	if _focused == null:
		return
	get_viewport().set_input_as_handled()
	_focused.interact(actor if actor != null else owner)

func _on_area_entered(area: Area2D) -> void:
	if area is Interactable and not _nearby.has(area):
		_nearby.append(area)
		_refresh_focus()

func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		_nearby.erase(area)
		_refresh_focus()

func _refresh_focus() -> void:
	for index in range(_nearby.size() - 1, -1, -1):
		var item := _nearby[index]
		if not is_instance_valid(item) or not item.enabled:
			_nearby.remove_at(index)
	var next_focus: Interactable = null
	var best_distance := INF
	for item: Interactable in _nearby:
		var distance := global_position.distance_squared_to(item.global_position)
		if distance < best_distance:
			best_distance = distance
			next_focus = item
	if next_focus == _focused:
		_update_prompt()
		return
	_focused = next_focus
	focus_changed.emit(_focused)
	_update_prompt()

func get_focused() -> Interactable:
	_refresh_focus()
	return _focused

func _update_prompt() -> void:
	if prompt_label == null:
		return
	prompt_label.visible = _focused != null
	prompt_label.text = "[%s] %s" % [InputPrompts.get_action_prompt(action), _focused.get_prompt_text()] if _focused != null else ""

func _on_prompt_context_changed(_value: Variant = null) -> void:
	_update_prompt()

func _on_locale_changed(_locale: String) -> void:
	_update_prompt()
