class_name GameSetup
extends GameModule

## The game's own module, installed with the modules it enables
## (`GameModules`): what only this game knows, such as the kinds of content of
## its own (`ContentDB.register_kind()`), the tool actions and buff stats its
## code handles, its new-game steps, and the data a module reads from a slot
## the game fills. See games/farm1/game/game_setup.gd.

func install() -> void:
	pass
