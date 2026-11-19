extends Control

## The game's first scene: the hero has one life, so it continues the save of
## the first slot when there is one and starts a new game otherwise, with no
## title screen in between. A save this build cannot read starts afresh.

func _ready() -> void:
	SaveManager.select_slot(1)
	SaveManager.load_completed.connect(_on_load_completed, CONNECT_ONE_SHOT)
	if SaveManager.has_save():
		GameSession.continue_game()
	else:
		SaveManager.load_completed.disconnect(_on_load_completed)
		GameSession.start_new_game()

func _on_load_completed(success: bool, _message: String) -> void:
	if not success:
		GameSession.start_new_game()
