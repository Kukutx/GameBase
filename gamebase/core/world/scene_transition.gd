class_name GameSceneTransition
extends CanvasLayer

const FADE_SECONDS := 0.12

var _overlay: ColorRect
var _busy := false

func _ready() -> void:
	layer = 1000
	_overlay = ColorRect.new()
	_overlay.name = "FadeOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.02, 0.03, 0.035, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

func change_scene(path: String) -> void:
	if _busy or path.is_empty():
		return
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		push_error("Transition: scene is unavailable: %s" % path)
		return
	_busy = true
	var animate := DisplayServer.get_name() != "headless" and not GameSettings.reduced_motion
	if animate:
		_overlay.visible = true
		var fade_out := create_tween()
		fade_out.tween_property(_overlay, "color:a", 1.0, FADE_SECONDS)
		await fade_out.finished
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		push_error("Transition: scene change failed (%d): %s" % [error, path])
		_overlay.visible = false
		_overlay.color.a = 0.0
		_busy = false
		return
	if animate:
		await get_tree().process_frame
		var fade_in := create_tween()
		fade_in.tween_property(_overlay, "color:a", 0.0, FADE_SECONDS)
		await fade_in.finished
		_overlay.visible = false
	_busy = false
