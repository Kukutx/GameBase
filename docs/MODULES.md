# Writing a module

A module is an optional piece of gameplay under `tiamat/modules/<module>/` that every game listing it in its `game.json` shares: `items`, `skills`, `damage`, `dialogue`, `combat`, `lifesim`, `npc_social`, `npc_ai`, `progression`, `roguelite`, `rts` and `tactics` today. A module is written once and wires itself into the core; a game only lists it. What only one game needs stays in that game's `game/`, and something every game needs belongs in `tiamat/core/`.

The reference pages list what the foundation already offers: [autoloads](reference/autoloads.md), [events](reference/events.md) and [rule keys](reference/rules.md).

## Layout

```text
tiamat/modules/<module>/
  <module>_module.gd        <Module>Module, a GameModule: install() wires the module into the core
  <module>_events.gd        <Module>Events, an autoload: the module's signals, if others react to it
  <module>_rules.gd         <Module>Rules: the condition and action keys content can name, if any
  <feature>/                its content classes, services, scenes and data, one directory per feature
  i18n/<module>.zh_CN.po    the Simplified Chinese text of the module's own strings
  test/                     its GUT tests, which every game that links the module runs
```

`skills` is the smallest complete example: `skills_module.gd`, `skills_rules.gd`, the `SkillData` content class, the `Skills` service, its catalog and its tests.

## Declare it

`node tools/new_module.js --id <id> [--requires <module>,...]` starts one: it writes `<id>_module.gd` (an empty `install()`), an empty catalog and a test that the module installs itself, and declares it in `tiamat/tiamat.json`. List it in a game's `game.json` and run `node tools/link.js`; the game's import writes the scripts' `.uid` files, which the code check asks for.

Each module is declared in `tiamat/tiamat.json`:

```json
"skills": {
  "requires": [],
  "autoloads": { "Skills": "res://tiamat/modules/skills/skill_manager.gd" }
}
```

- `requires` lists the modules it uses. Requirements form no cycle, so a game can take a module with only the modules below it. A module may use the core and the modules it requires, never a game; `tools/check_layers.js` enforces both.
- `addons` lists the shared addons under `addons/` it uses (`dialogue`, `npc_social` and `npc_ai` use `dialogue_manager`).
- `autoloads` are its services. `node tools/link.js` writes them into each game's `project.godot` after the core's first group and after the autoloads of the modules it requires.

## Wire it in: `<Module>Module`

The core's `GameModules` autoload installs every `GameModule` class the game links, so the wiring lives in the module and no game repeats it. `install()` runs before any module service's `_ready()` and before content is indexed, so it only registers; it reads no content and no state.

```gdscript
class_name SkillsModule
extends GameModule

func install() -> void:
	ContentDB.register_kind(SkillData.KIND, SkillData)
	GameStats.register_source(Skills)
	SkillsRules.register(GameRules)
	SaveManager.register_section(SaveSection.new(&"skills", 1100,
		Skills.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Skills.load_save_data(section)))
	GameSession.register_new_game_step(&"skills", 800, Skills.reset_new_game)
```

What a module can register:

| With | Call | For |
| --- | --- | --- |
| `ContentDB` | `register_kind(KIND, script)`, `register_check(callable)` | its kinds of content, and checks of the whole content (a graph without cycles) |
| `GameRules` | `register_condition()`, `register_action()`, `register_arg_kind()` | the keys content can name in conditions and actions |
| `GameStats` | `register_stat()`, `register_source()` | the numbers it reads, each with the name the player knows it by, and what changes them |
| `SaveManager` | `register_section()`, `register_load_step()`, `register_save_blocker()`, `register_slot_detail()` | what it saves, what runs after a load, when it cannot save, and a line on the title screen's slot |
| `GameSession` | `register_new_game_step()`, `register_activity_end()` | how a new game resets it, and how passing out, a load, a new game or the title ends what it holds the player in |
| `PauseMenu` | `add_page(id, title, order, lines)` | a page of lines the pause menu offers while it has any (the items module's Items, the skills module's Skills, the combat module's Bestiary); a game leaves one out with its pause menu's `hidden_pages` |
| `ItemSources` (items module) | `register(id, finder)` | the ways the player gets the items the module gives (a shop's stock, an enemy's drop, a quest's reward), which the menus show and `test_item_sources` checks every item has |

Each registration that takes an order interleaves with the core's own (`GameSaveManager.SECTION_ORDER_*`, `GameSessionService.NEW_GAME_ORDER_*`) and the other modules'; read the comments on the existing ones before choosing one.

Three more methods of `<Module>Module` answer rather than register. `get_controls()` names the controls the module's systems read (`ControlAction`), which the settings let the player rebind. `get_options()` names the choices its systems leave to the player (`GameOption`: a switch, one of a few named choices or a number in a range), which the settings show and keep (`GameSettings.get_option()`); a system reads its option where it acts, so a change holds at once (the dialogue module's `auto_advance_dialogue`, read as each line shows), and a choice that scales a number reads it with `GameOptions.scale_of()` (the combat module's `damage_taken`, the rts and tactics modules' battle speeds), and content reads one as a condition (`OPTION <option> <value>...`, `OPTION_AT_LEAST`). Declare one as a `.tres` resource, as the controls are, so the localization check finds its name and choices. `get_facts()` tells the state of the module's systems as plain data by section (`SkillsModule`: `{"skills": {"farming": {"level": 3, "xp": 420}}}`), which `GameModules.get_facts()` gathers for whatever describes the game without knowing its modules, such as what an NPC knows when it talks (`NpcContext`). A lower module tells its own state this way instead of a higher one reaching down for it.

## Content

Each kind of content is a class that extends `ContentEntry`, declares `const KIND`, and gives static `find(id)` and `find_all()` that read `ContentRegistry.active`. Its `find_problems(registry)` returns what is wrong with an entry: missing fields and references to unknown ids. A node in a location's scene that refers to content implements `find_scene_problems(registry, location)`. `ContentDB` asks both while it indexes, and a problem fails validation. Code always reads content through these classes, never through `ContentDB` directly, so a test's fixture content reaches it.

Nothing in the module names a game's ids. When it needs one (the location of a mine, the item a quest starts with), it reads it from a slot the game fills: an exported property set in the game's scene, a field of the game's data, or `GameDefinition`.

## State and saves

A service keeps its state in the autoload and saves it in a section of its own, or keeps it in `WorldState` under keys of its own, which the `world` section saves. Any change to what a save holds raises `GameSaveManager.SAVE_VERSION`; there is no migration. `.agents/rules/save.md` has the full checklist, including the new-game step every saved state needs.

## Events and rules

- `<Module>Events` declares the signals of what happened in the module (an item crafted, a fish caught). Only the module emits them; higher modules, the game, triggers and quest objectives listen (`"<Module>Events.<signal>"`, `GameEvent`), so a module that counts or rewards what happens elsewhere listens to an event named in content rather than to another module's code. An argument that holds a content id is named `<kind>_id` after its kind (`crop_id`, `mining_node_id`, or `result_item_id` for an item that is a result), which lets content checks verify the ids compared with it.
- `<Module>Rules.register(rules)` registers the module's keys. Each handler has a doc comment `## KEY <arg> [optional]: what it means.`, which the [rule keys](reference/rules.md) page shows.

After changing an autoload, a signal or a rule key, run `node tools/generate_reference.js`; validation fails while a reference page differs from the code.

## Text

Every string the player reads is a literal in a `tr()` call, a toast or a prompt, or a text property of a scene or a resource. Its Simplified Chinese entry goes in the module's `i18n/<module>.zh_CN.po`, never in the core's or a game's catalog, and `node tools/check_localization.js` checks every game that links the module. `docs/LOCALIZATION.md` has the rules.

## Tests

The module's tests live in its `test/` directory, and every game that links the module runs them, after the core's. A test does not assume a game's content, calendar, weather or controls: `ContentFixture.use()` puts fixture content in place, `ContentFixture.use_calendar()` a calendar and `ContentFixture.use_weather()` the odds of each season's weather. Validation runs every module's tests in a game made from the template with every module, which gives them nothing of its own. `.agents/rules/testing.md` has the conventions.

## Use it in a game

1. List the module, with every module it requires, under `modules` in `games/<id>/game.json`.
2. Run `node tools/link.js`: it links the module into the game and registers its autoloads and catalog in `project.godot`.
3. Run `node tools/validate.js --game <id>`.
