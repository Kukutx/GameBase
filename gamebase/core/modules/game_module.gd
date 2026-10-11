class_name GameModule
extends RefCounted

## A gameplay module's wiring into the core.
##
## Each module under `gamebase/modules/` ships one subclass, and each game one
## of its own (`game/game_setup.gd`). The `GameModules` autoload installs every
## subclass the game links, so enabling a module in a game's `game.json` is
## enough to wire it: no game repeats a module's kinds of content, save
## sections or steps. `install()` registers what the core runs for the module,
## such as kinds of content and content checks (`ContentDB`), rule keys
## (`GameRules`), save sections, load steps and save blockers (`SaveManager`)
## and new-game steps (`GameSession`). Orders interleave with the core's own
## (`GameSaveManager.SECTION_ORDER_*`, `GameSessionService.NEW_GAME_ORDER_*`).
##
## Modules install before any module service's `_ready()` and before content
## is indexed: `install()` only registers, and reads no content and no state.

func install() -> void:
	pass
