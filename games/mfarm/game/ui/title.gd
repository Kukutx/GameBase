extends GameTitleScreen

## MFarm's title screen: the core's menu on the old game's paper, under its
## title in the old brush font (麦田物语 in Chinese), with the keys its menu
## told of beneath. The old menu showed the title alone on the paper, so the
## description stays in the project settings.

func _ready() -> void:
	super()
	subtitle_label.visible = false
