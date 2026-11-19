class_name MFarmDialogueLine
extends Resource

## One line of a conversation, with the face of who says it on one side.

@export var speaker: String
@export_multiline var text: String
@export var portrait: Texture2D
@export var on_left := true
