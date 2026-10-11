class_name MiniGameDefinition
extends ContentEntry

## A minigame the game can start through `MiniGameHost.run()`.

## Scene whose root extends `MiniGame`.
@export var scene: PackedScene
## Pauses the world (clock, actors, other menus) while the minigame runs.
@export var pause_world := true
## Actions (`GameRules` syntax) run when the player wins or loses.
@export var success_actions: PackedStringArray = PackedStringArray()
@export var failure_actions: PackedStringArray = PackedStringArray()
## Tuning passed to the minigame's `setup()`; the caller's context overrides it.
@export var settings: Dictionary = {}
