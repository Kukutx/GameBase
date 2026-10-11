---
path: "gamebase/core/test/**, gamebase/modules/*/test/**, games/*/test/**"
---

# Testing and verification (`gamebase/core/test/**`, `gamebase/modules/*/test/**`, `games/*/test/**`)

`node tools/validate.js` is the single local entry point (`--game <id>` limits it to one game); `docs/RELEASE.md` lists what it and `node tools/release_readiness.js` run. This page covers how tests are written here and how a result is reported. The engine behaviour described was confirmed on Godot 4.7.2.

## P0

- **What fails a Godot step**: a non-zero exit code or any `ERROR:` / `SCRIPT ERROR:` line in its output. The engine exits with code 0 after parse errors, missing autoloads and `push_error()` calls, so the exit code alone proves nothing.
- **A test does not provoke an engine error on purpose**: the line it prints fails the whole GUT step. Validation logic is therefore written as functions that return or append their messages (`ContentEntry.find_problems(registry)`, `ContentRegistry.find_dependency_cycles(...)`) and tests assert on those messages; only the top-level caller reports with `push_error`.
- **The import step compiles no gameplay scripts**: a syntax error or a type error in a script, with or without `class_name`, and a scene that uses a broken script all pass `--import` without a single line of output. A script is compiled when something loads it. Autoload scripts are loaded at startup, so their errors do appear; everything else is reached only when a test or one of the smoke runs loads the script or a scene that uses it. `games/farm1/test/unit/test_project_scripts_and_scenes.gd` loads every script and scene under its `res://game` and `res://gamebase` for that reason; a script it cannot reach needs a test that instantiates it.
- **Three states, kept apart**: passed, failed, and not verified. "Not verified" names the step that did not run and why (no baseline engine, no export templates, no browser, working tree not clean for `tools/release_readiness.js`). It is never folded into "passed".
- **A step counts as passed only for this round**: it ran in the current session after the last change to the files it covers, and its output was read.
- **A result depends on the engine that produced it**: `tools/validate.js` warns and continues when the local engine differs from `.godot-version`. A result that depends on engine behaviour counts only when it was produced with the baseline version; check the `Godot:` line the script prints.

## P1

- **Unit tests run inside the real project**: they extend `GutTest` and run inside a game with every autoload active. There are no doubles or stubs; tests build real objects and call the real services.
- **A test lives with the layer it tests**: a test of the core lives in `gamebase/core/test/`, a test of a module in `gamebase/modules/<module>/test/`, and a test of a game's own code or content in `games/<id>/test/unit/`. `node tools/link.js` lists the core's and the linked modules' test directories in each game's `.gutconfig.json`, so every game runs the tests of the foundation it uses, and the new-game check runs the core's tests in a game with no module. A foundation test names no game's ids (`tools/check_layers.js` holds it to that like any foundation file): it builds the content it needs and makes it the only content with `ContentFixture.use()` (`gamebase/core/test/content_fixture.gd`), registers a stat its content changes with `ContentFixture.add_stat()`, and starts a service that reads the game's definition with `ContentFixture.with_definition()`. A game's tests keep only what is the game's own: its content and balance, its scenes, its code and its wiring of module events.
- **Fixture content is active until GUT frees it, after `after_each()`**: a test that uses `ContentFixture.use()` and restores a service in `after_each()` makes `ContentRegistry.active = ContentDB` the first line of `after_each()`, or the service would load its snapshot against the fixture content and drop the game's entries.
- **Autoload state outlives a test**: a test that changes a service saves that service's state in `before_each()` with `to_save_data()` and restores it in `after_each()` with `load_save_data()` (`InventoryState`, `WorldState`, `PlayerState`, `WorldClock`, `Skills`, `QuestState` and the others all follow this). Leaving state behind makes a later test file fail for a reason unrelated to its own code.
- **Nodes a test creates are freed by the test**: they are added with `add_child_autofree()` and other objects are wrapped in `autofree()`; the test then waits a frame (`await get_tree().process_frame`) before reading anything set in `_ready()`.
- **Headless runs skip the non-headless branches**: tests run headless, and so does the native exported-build smoke (`tools/smoke_export.js`). Branches guarded by `DisplayServer.get_name() != "headless"` (the fade in `WorldTravel` and `GameSceneTransition`, window mode and vsync in `GameSettings`) are executed by none of them; only the browser smoke of the Web export and a manual run reach that code.
- **A run does not inherit the developer's language**: `games/farm1/test/gut_pre_run.gd` and Farm1's runtime scripts set the locale to `en`, because the settings service loads the language saved on the machine and tests compare text with the English source strings. A test that needs another language sets `TranslationServer` itself and restores it.
- **Input reaches `_input()` only as an event**: a test that has to reach `_input()` or `_unhandled_input()` sends an event with `Input.parse_input_event()`. `Input.action_press()` only changes what polling returns.
- **`WARNING:` lines do not fail a step**: read them all the same; an invented `uid://` in a scene or resource, for example, shows up only as a warning.
- **`--check-only -s <script>` is not a parse check**: it reports `Identifier not found` for every autoload a valid script names, and nearly every script here names one.
- **One layer of evidence proves one layer**: an import or parse check does not show that a scene runs, a unit test does not show that a menu can be operated, and a headless run does not show what the screen looks like. Judging a screenshot by eye, or a similarity score, is an observation that helps locate a problem; it does not turn a failed or unverified check into a pass.

## Related

- Operating the running game to find, reproduce and fix a defect: `.agents/skills/game-qa/SKILL.md`.
- Matching a reference so that named dimensions agree exactly: `.agents/skills/replication/SKILL.md`.
- What `node tools/validate.js` and `node tools/release_readiness.js` run: `docs/RELEASE.md`.
