---
path: "games/*/test/**"
---

# Testing and verification (`games/*/test/**`)

`node tools/validate.js` is the single local entry point (`--game <id>` limits it to one game); `docs/RELEASE.md` lists what it and `node tools/release_readiness.js` run. This page covers how tests are written here and how a result is reported. The engine behaviour described was confirmed on Godot 4.7.2.

## P0

- **What fails a Godot step**: a non-zero exit code or any `ERROR:` / `SCRIPT ERROR:` line in its output. The engine exits with code 0 after parse errors, missing autoloads and `push_error()` calls, so the exit code alone proves nothing.
- **A test does not provoke an engine error on purpose**: the line it prints fails the whole GUT step. Validation logic is therefore written as functions that return or append their messages (`ContentDB._validate_references(errors)`, `_collect_dependency_cycle_errors(...)`) and tests assert on those messages; only the top-level caller reports with `push_error`.
- **The import step compiles no gameplay scripts**: a syntax error or a type error in a script, with or without `class_name`, and a scene that uses a broken script all pass `--import` without a single line of output. A script is compiled when something loads it. Autoload scripts are loaded at startup, so their errors do appear; everything else is reached only when a test or one of the smoke runs loads the script or a scene that uses it. `games/farm1/test/unit/test_project_scripts_and_scenes.gd` loads every script and scene under its `res://game` and `res://gamebase` for that reason; a script it cannot reach needs a test that instantiates it.
- **Three states, kept apart**: passed, failed, and not verified. "Not verified" names the step that did not run and why (no baseline engine, no export templates, no browser, working tree not clean for `tools/release_readiness.js`). It is never folded into "passed".
- **A step counts as passed only for this round**: it ran in the current session after the last change to the files it covers, and its output was read.
- **A result depends on the engine that produced it**: `tools/validate.js` warns and continues when the local engine differs from `.godot-version`. A result that depends on engine behaviour counts only when it was produced with the baseline version; check the `Godot:` line the script prints.

## P1

- **Unit tests run inside the real project**: they extend `GutTest`, live in a game's `games/<id>/test/unit/`, and run inside that game with every autoload active. The foundation's own unit tests live in Farm1 today, because they need content from every module. There are no doubles or stubs; tests build real objects and call the real services.
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
