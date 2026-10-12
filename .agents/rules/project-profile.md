# GameBase project profile

This file describes only what is specific to this repository. The generic engineering boundaries are in `.agents/rules/project.md`.

## Repository identity

- GameBase is an open-source monorepo: a reusable Godot 4.x foundation and every game built on it. Later generations, games of other genres and in-game minigames all live here; a new game is a new `games/<id>/`, never a new repository, and nothing here depends on another repository. A fix to the foundation is made once in `gamebase/` and reaches every game in the same change.
- `gamebase/` holds the foundation: `gamebase/core/` genre-agnostic services, `gamebase/modules/<module>/` optional gameplay modules, `gamebase/templates/new_game/` the template a new game starts from, and `gamebase/gamebase.json` the modules, what each requires and the addons each uses. `addons/` holds the vendored third-party addons every game shares. `games/<id>/` is one Godot project per game: `game.json` (its modules, extra addons, own autoloads and licensed art), `project.godot`, `export_presets.cfg`, `game/` its own code and data and `test/` its GUT tests (`test/unit/`) and runtime scripts (`test/runtime/`). The core's and each module's own GUT tests live in their `test/` directory. `tools/` holds Node tooling and `docs/` the project documentation.
- A game sees the foundation and the addons through links `node tools/link.js` creates inside it (`res://gamebase/core`, `res://gamebase/modules/<module>`, `res://addons/<addon>`); they are Git-ignored and never edited through the game. `tools/check_layers.js` keeps dependencies one-way: game → listed modules → the modules they require → core, and the modules' requires in `gamebase/gamebase.json` form no cycle.
- The registered games: Farm1 (`games/farm1/`), the first-generation farming life-sim, which uses every module; Ember Depths (`games/dungeon1/`), a dungeon delve on the core, items, skills and combat, which keeps the foundation honest for a second genre.
- Prefer a small, clean game layer over carrying unused demo or editor systems from the template the project started from. The inherited `addons/top_down` and `addons/great_games_library` runtime stacks were removed and must not come back as hidden dependencies.
- `Godot-GameTemplate` is the upstream foundation and the visual and reference baseline. Reference repositories live outside this repository under `../GodotReferences/GameBaseReferences/` and are not production dependencies.
- The agent instruction tree is the root `AGENTS.md` plus the host-neutral `.agents/` directory. Skills live in `.agents/skills/`; a host that does not register that directory reaches the same `SKILL.md` files through the conditional-context table in `AGENTS.md`, so no second copy of a skill is kept for another host. Do not add `CLAUDE.md` or another duplicate instruction file; `tools/release_readiness.js` rejects one.

## Versions

- Each game has its own version, kept only in `config/version` of `games/<id>/project.godot`. Change it only through `node tools/update_game_version.js --game <id> --version <semver>`. A release tag is exactly `game/<id>/v<version>`. The foundation has no version of its own: every game builds from the foundation in the same commit. Game versions are independent of the engine baseline.
- The project targets the current stable Godot 4.x line. The CI validation baseline lives in `.godot-version`; it is a validation baseline, not a permanent engine lock, and newer stable 4.x releases are allowed locally.
- Move the shared baseline only through `node tools/update_engine_baseline.js --version <x.y.z>`, which updates `.godot-version`, `licenses/GODOT_VERSION.txt` and the matching official Godot LICENSE and COPYRIGHT bundle together. Then confirm addon compatibility, run `node tools/validate.js` and verify every export preset. Development and release-candidate engine builds do not become the shared baseline unless explicitly requested.
- Keep the feature marker in each game's `project.godot` on the oldest feature level the project actually needs. Do not raise it merely to match a patch release.
- Procedure and reasons: `docs/ENGINE_UPGRADES.md`.

## Dependencies

- Prefer built-in Godot capabilities. When a mature solution already exists, prefer a mainstream, actively maintained Godot 4.x addon over rebuilding the same infrastructure.
- An addon must show clear maintenance activity, broad community use, compatible releases and an acceptable license. Avoid abandoned, obscure or single-purpose dependencies that are easy to implement locally.
- The approved addons and how they are kept are in `.agents/rules/addons.md`.
- Tooling under `tools/` is plain Node with no packages of its own; the only npm package is Playwright for the Web smoke under `tools/web_smoke/`.

## Default evolution strategy and language

- `default_evolution`: `greenfield`. The project is experimental and has no published saves or builds to protect: every change uses the current best solution, with no compatibility code, migrations, shims or fallbacks for earlier formats, data or interfaces. Each game's version starts at 0.1.0, the save format's version only rises when the format changes (there is no migration), and dependencies track the newest stable releases. Stable ids still never change meaning, because a derived game's data refers to them.
- The current fact roots are the code, `gamebase/gamebase.json`, each game's `game.json`, data resources under `game/data/`, `project.godot` and `export_presets.cfg`, and the pages under `docs/`.
- Documentation, code comments and commit messages are in English. Commit subjects follow the Conventional Commits style of the existing history. A comment describes what the code does now and why, not what it used to do.
- Stable gameplay ids, save keys, resource ids and enum values are never translated. Generated files and vendored addon sources are not rewritten for style.

## Release infrastructure

- Each game's `export_presets.cfg`, the CI workflows, the validation and release tools, the deterministic packager, the browser and native smoke tooling, the release notices and licenses and the release documentation are production infrastructure and stay under version control.
- Release packs exclude the game's `test/`, `addons/gut/`, `game.json`, `.gutconfig.json`, the local licensed source art, repository and development tooling, the agent instruction tree and legal or documentation files; `tools/verify_export_contents.js` enforces this by mounting each exported pack.
- A normal release export uses the shared engine baseline. `--allow-engine-drift` is reserved for explicit compatibility or test artifacts and synchronizes a temporary legal bundle to the stable engine actually used. License and notice files are copied beside the executable or Web payload after the pack has been verified.
- Before a release candidate run `node tools/release_readiness.js --game <id>`. Details: `docs/RELEASE.md`.

## Facts and procedures

| To decide | Read |
| --- | --- |
| Domain invariants: content, save compatibility, audio, travel, dialogue, licensed art | `.agents/rules/project-domain.md` |
| Release process, CI jobs, publishing | `docs/RELEASE.md`, then `.agents/prompts/recipes/release.md` |
| Engine and addon upgrade policy | `docs/ENGINE_UPGRADES.md`, then `.agents/skills/toolchain/SKILL.md` |
| Localization rules and the coverage gate | `docs/LOCALIZATION.md` |
| Audio routing and cue ids | `docs/AUDIO.md` |
| Licensed local art | `docs/LICENSED_ASSETS.md` |
| The foundation's layers, modules and links, and adding a game | `gamebase/README.md` |
| Diagnostics and support bundles | `docs/SUPPORT.md` |
| Automation levels, escalation to a person and the executable entry points of each area | `docs/AUTOMATION.md` |
| Third-party syntax, APIs, versions, or agent host guidance | `docs/OFFICIAL_DOCS.md`, then the official page that matches |
| The fixed release, engine upgrade, game QA, diagnostics and CI recipes of this repository | `.agents/prompts/agent-prompt-shortcuts.md`; open only the recipe that matches |

## Tool discovery

- Every tool is a script run as `node tools/<name>.js`; `node tools/validate.js` is the single local validation entry point. A tool that acts on one game takes `--game <id>`, else `GAMEBASE_GAME`, else the only registered game; repository-wide steps run once for all games. Flags and behaviour come from the script itself; read it rather than guessing from `--help` output.
- The engine used by a tool is `--godot-bin <path>`, else the `GODOT_BIN` environment variable, else `godot` on `PATH`. A result that depends on engine behaviour counts only when the engine matches `.godot-version`.
- Write-type commands, side effects, dependencies, Git and third-party authorization are judged by the matching boundary in `.agents/rules/project.md`.
