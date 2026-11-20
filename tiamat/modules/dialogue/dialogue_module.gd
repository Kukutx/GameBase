class_name DialogueModule
extends GameModule

## Wires the dialogue module into the core (see `GameModule`): the choice to
## let a conversation move on by itself once the player has had time to read
## a line (`DialogueBalloon.AUTO_ADVANCE_OPTION`).

const OPTIONS: Array[String] = [
	"res://tiamat/modules/dialogue/options/auto_advance.tres",
]

func get_options() -> Array[GameOption]:
	var options: Array[GameOption] = []
	for path: String in OPTIONS:
		options.append(load(path) as GameOption)
	return options
