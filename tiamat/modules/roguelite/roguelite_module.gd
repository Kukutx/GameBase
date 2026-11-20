class_name RogueliteModule
extends GameModule

## Wires the roguelite module into the core (see `GameModule`): runs, which
## block saving while they go on and end, abandoned, when something takes the
## player out of play, and the boons a run takes (`BoonData`), which change
## stats while it goes on.

func install() -> void:
	ContentDB.register_kind(BoonData.KIND, BoonData)
	GameStats.register_source(RunState)
	RogueliteRules.register(GameRules)
	SaveManager.register_save_blocker(RunState.get_save_block_reason)
	GameSession.register_activity_end(RunState.abandon)
