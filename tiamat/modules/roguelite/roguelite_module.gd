class_name RogueliteModule
extends GameModule

## Wires the roguelite module into the core (see `GameModule`): runs, which
## block saving while they go on and end, abandoned, when something takes the
## player out of play.

func install() -> void:
	RogueliteRules.register(GameRules)
	SaveManager.register_save_blocker(RunState.get_save_block_reason)
	GameSession.register_activity_end(RunState.abandon)
