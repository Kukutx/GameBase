class_name LicensedArtSprite
extends Sprite2D

@export_file("*.png") var asset_path: String
@export var hide_when_missing := true

func _ready() -> void:
	if asset_path.is_empty() or not ResourceLoader.exists(asset_path):
		if hide_when_missing:
			visible = false
		return
	var loaded := load(asset_path) as Texture2D
	if loaded == null:
		if hide_when_missing:
			visible = false
		return
	texture = loaded
	visible = true
