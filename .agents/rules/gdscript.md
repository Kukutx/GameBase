---
path: "gamebase/**/*.gd, games/*/game/**/*.gd, games/*/test/**/*.gd"
---

# GDScript (`gamebase/**/*.gd`, `games/*/game/**/*.gd`, `games/*/test/**/*.gd`)

Each statement below was confirmed either by running Godot 4.7.2 headless or by reading this repository's code. Tutorials and third-party agent skills still mix Godot 3 and early Godot 4 APIs, and several of them describe features that do not exist; when one disagrees with the class reference of the engine version in `.godot-version`, the class reference wins. Re-check this rule when the shared baseline moves.

## P0

- **An autoload name and a `class_name` differ**: a script registered as autoload `GameThing` that also declares `class_name GameThing` fails with `Class "GameThing" hides an autoload singleton`, and the engine still exits with code 0. The convention here pairs them as `GameAudio` / `GameAudioService`, `SaveManager` / `GameSaveManager`, `GameEvents` / `GlobalGameEvents`.
- **The autoload order is the initialisation order**: the `[autoload]` order in the game's `project.godot` decides it, and `node tools/link.js` writes that section from `gamebase/gamebase.json`: the core's `before_modules` autoloads, each module's autoloads (a module after the modules it requires), the core's `after_modules` autoloads, then the game's own from `game.json`. Inside `_init()` the autoloads listed later do not exist yet; inside `_ready()` they are in the tree but their own `_ready()` has not run. Declare a new service in `gamebase.json` below every service whose state it reads in `_ready()`, or defer the read the way `GameAudio` defers `_sync_location_music`.
- **A write is known to have succeeded only when it returned `true`**: `FileAccess.store_string()` and the other `store_*` methods return `false` when the write fails; a successful `FileAccess.open()` says nothing about it.
- **Text typed by the player is escaped before it reaches BBCode**: a `RichTextLabel` with BBCode enabled interprets tags inside any value formatted into its text. Text typed by the player (animal names, for example) has every `[` replaced with `[lb]` before it is inserted; unescaped, a name of `[i]Bessie[/i]` is displayed as an italic `Bessie`.
- **An engine error line fails validation**: `tools/validate.js` fails a Godot step on any `ERROR:` or `SCRIPT ERROR:` line, so these matter even when nothing else goes wrong:
  - `JSON.parse_string()` on invalid text returns `null` and prints `ERROR: Parse JSON failed`. For text that may be invalid use `JSON.new().parse()`, which returns an error code and prints nothing, as `GameSaveManager._read_dictionary` does.
  - Connecting a callable to a signal it is already connected to returns an error code and prints `ERROR: Signal ... is already connected`.
  - A `push_error()` reached during a test or smoke run fails that step even when every assertion passes.
  - `resources still in use at exit` after a GUT run that passed can come from Godot 4.7.2's GDScript shutdown, which skips the remaining scripts when clearing one frees the next. Typing `GameDefinition.controls` as `Array[ControlAction]` triggered it; that is why the export is `Array[Resource]`. Bisect a new occurrence by reverting changes to scripts the autoloads load, not by looking for a missing `free()`.
- **Controls are declared as `ControlAction` resources**: `GameSettings` builds the input map at startup from the game's `GameDefinition.controls` and the core's own controls (`gamebase/core/input/controls/`: interact, quick save, quick load), erasing whatever those actions had. Their events therefore never go in the `[input]` section of a game's `project.godot`, which keeps only Godot's `ui_*` actions and debug keys. Add or change a game's action as a `ControlAction` in its `game/game_definition.tres`; a control with a core control's action replaces it. `ContentRegistry.rebuild()` reports a rebindable control without a name or a default key, and two rebindable controls that share a key.
- **The motion mode of an actor is a gameplay decision**: the player, NPCs, animals and enemies are `CharacterBody2D` nodes left on the default grounded motion mode. Switching one to `MOTION_MODE_FLOATING`, which generic top-down advice recommends, changes how it slides along walls: with a velocity of (100, 100) pushed against a wall for 40 physics frames, the grounded body travelled 65–67 px along the wall and the floating body 88 px. Treat that switch as a gameplay change that needs a decision, not as a cleanup.

## P1

- **Gameplay randomness comes from `GameRandom`**: a roll that decides what the player gets or meets (weather, a catch, a drop, a layout) takes a stream keyed by what it rolls, `GameRandom.stream("forage:%d:%s" % [day, spawner])`, never `randf()`, `randi()` or a `RandomNumberGenerator` (its algorithm may change with the engine), so a load replays it on any engine version and a test pins it by the seed. The global generator is only for cosmetic jitter such as a sound's pitch.
- **Nothing required goes behind `await tween.finished`**: code after it never runs when the node the tween is bound to is freed first. Do not put a required cleanup, state reset or signal emission behind such an `await`.
- **Re-check state after every `await`**: state can change while a coroutine is suspended, and the same function can be entered again before the first call resumes. `GameSession` (`_handling_defeat`, `_handling_late_night`) and `GameSceneTransition` (`_busy`) show the guard this project uses.
- **A new tween does not stop the earlier one**: `create_tween()` leaves an earlier tween running, and two tweens on the same property fight over the value. Keep the reference and `kill()` it before starting another, or serialise the calls with a guard.
- **A loaded resource is shared**: `load()` returns the same cached instance for a path. Data resources obtained from `ContentDB` are shared definitions; runtime state never goes into them.
- **A copy is only as deep as asked**: `Resource.duplicate(true)` copies built-in sub-resources but keeps sharing sub-resources stored in their own file. `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` copies those as well. `duplicate()` with no argument also shares the arrays and dictionaries the resource holds.
- **Assigning an array element does not call the setter**: `obj.values[i] = x` does not call that property's setter, for packed and plain arrays alike. Reassign the whole property when the setter has to run.
- **A lambda captures a copy of each local variable**: assigning to a captured local inside the lambda leaves the outer variable unchanged; share state through a member variable or a container.
- **`call_group()` skips nodes that lack the method**: it does so silently, so a misspelled method name does nothing.
- **A `static var` outlives the scene**: it keeps its value across `reload_current_scene()` and scene changes.
- **`Input.action_press()` does not deliver an event**: it changes what `Input.is_action_pressed()` returns but delivers nothing to `_input()` or `_unhandled_input()`. Gameplay and menu input in this project is handled in `_unhandled_input`, so a test that has to reach it sends an event with `Input.parse_input_event()`.

## P2

- Scripts are statically typed: typed variables, parameters and return values, typed arrays, `:=` where the type is obvious.
- A script that other code refers to declares `class_name`; signals are declared at the top and carry typed parameters.
- Ids are `StringName` literals (`&"turnip"`). A value that arrived from a save, a dictionary or a signal with a looser type is converted with `StringName(String(value))` before it is used as an id.
- Player-visible text never appears as a bare literal assigned to a control; see `.agents/rules/localization.md`.
- A new script gets a `.gd.uid` file from the import step; see `.agents/rules/scenes-resources.md`.

## Verification

`node tools/validate.js --skip-soak` while iterating; without `--skip-soak` when the change touches save data or day progression. A script is compiled only when something loads it (`.agents/rules/testing.md`), so a new script is covered by a test that instantiates it.
