class_name GameModule
extends RefCounted

## A gameplay module's wiring into the core.
##
## Each module under `gamebase/modules/` ships one subclass. The `GameModules`
## autoload installs every subclass the game links, once all services exist and
## before the game's own setup, so enabling a module in a game's `game.json` is
## enough to wire it: no game repeats a module's save sections or steps.
## `install()` registers what the core runs for the module, such as rule keys
## (`GameRules`), save sections, load steps and save blockers (`SaveManager`)
## and new-game steps (`GameSession`). Orders interleave with the core's own
## (`GameSaveManager.SECTION_ORDER_*`, `GameSessionService.NEW_GAME_ORDER_*`).

func install() -> void:
	pass
