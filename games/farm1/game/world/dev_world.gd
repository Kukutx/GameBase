class_name DevWorldController
extends Node2D

func _enter_tree() -> void:
	if not WorldState.get_bool(GameSession.NEW_GAME_FLAG):
		GameSession.initialize_new_game_state()
		GameEvents.toast("New game initialized")
