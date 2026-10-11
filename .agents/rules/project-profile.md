# GameBase project profile

This file describes only what is specific to this repository. The generic engineering boundaries are in `.agents/rules/project.md`.

## Repository identity

- GameBase is an open-source Godot 4.x life-sim / RPG foundation: a reusable gameplay base rather than a finished content release. Games are derived from it; nothing in it depends on another repository.
- `gamebase/` holds the reusable foundation shared by every game: `gamebase/core/` genre-agnostic services and `gamebase/modules/<module>/` optional gameplay modules. `game/` holds this game's own code and data: `game/data/` resources indexed through `ContentDB`, `game/world/` playable locations and the world HUD, `game/npc/`, `game/player/`, `game/ui/` menus, `game/i18n/` translations. `addons/` holds vendored third-party code. `test/unit/` holds GUT tests and `test/runtime/` the end-to-end smoke and soak scripts. `tools/` holds Node tooling. `docs/` holds the project documentation.
- Prefer a small, clean game layer over carrying unused demo or editor systems from the template the project started from. The inherited `addons/top_down` and `addons/great_games_library` runtime stacks were removed and must not come back as hidden dependencies.
- `Godot-GameTemplate` is the upstream foundation and the visual and reference baseline. Reference repositories live outside this repository under `../GodotReferences/GameBaseReferences/` and are not production dependencies.
- The agent instruction tree is the root `AGENTS.md` plus the host-neutral `.agents/` directory. Skills live in `.agents/skills/`; a host that does not register that directory reaches the same `SKILL.md` files through the conditional-context table in `AGENTS.md`, so no second copy of a skill is kept for another host. Do not add `CLAUDE.md` or another duplicate instruction file; `tools/release_readiness.js` rejects one.

## Versions

- The application version lives in `.game-version` and must equal `application/config/version` in `project.godot`. Change both only through `node tools/update_game_version.js --version <semver>`. A release tag is exactly `v<game-version>`. This version is independent of the engine baseline.
- The project targets the current stable Godot 4.x line. The CI validation baseline lives in `.godot-version`; it is a validation baseline, not a permanent engine lock, and newer stable 4.x releases are allowed locally.
- Move the shared baseline only through `node tools/update_engine_baseline.js --version <x.y.z>`, which updates `.godot-version`, `licenses/GODOT_VERSION.txt` and the matching official Godot LICENSE and COPYRIGHT bundle together. Then confirm addon compatibility, run `node tools/validate.js` and verify every export preset. Development and release-candidate engine builds do not become the shared baseline unless explicitly requested.
- Keep the feature marker in `project.godot` on the oldest feature level the project actually needs. Do not raise it merely to match a patch release.
- Procedure and reasons: `docs/ENGINE_UPGRADES.md`.

## Dependencies

- Prefer built-in Godot capabilities. When a mature solution already exists, prefer a mainstream, actively maintained Godot 4.x addon over rebuilding the same infrastructure.
- An addon must show clear maintenance activity, broad community use, compatible releases and an acceptable license. Avoid abandoned, obscure or single-purpose dependencies that are easy to implement locally.
- The approved addons and how they are kept are in `.agents/rules/addons.md`.
- Tooling under `tools/` is plain Node with no packages of its own; the only npm package is Playwright for the Web smoke under `tools/web_smoke/`.

## Default evolution strategy and language

- `default_evolution`: `maintained` for everything a player's save or a derived game already depends on — the save schema, stable content, Location and Spawn ids, audio cue ids, exported resource fields. New systems are written for the current stable engine without compatibility layers for things that never shipped.
- The current fact roots are the code, the data resources under `game/data/`, `project.godot`, `export_presets.cfg` and the pages under `docs/`.
- Documentation, code comments and commit messages are in English. Commit subjects follow the Conventional Commits style of the existing history. A comment describes what the code does now and why, not what it used to do.
- Stable gameplay ids, save keys, resource ids and enum values are never translated. Generated files and vendored addon sources are not rewritten for style.

## Release infrastructure

- `export_presets.cfg`, the CI workflows, the validation and release tools, the deterministic packager, the browser and native smoke tooling, the release notices and licenses and the release documentation are production infrastructure and stay under version control.
- Release packs exclude `test/`, `addons/gut/`, the local licensed source art, repository and development tooling, the agent instruction tree and legal or documentation files; `tools/verify_export_contents.js` enforces this by mounting each exported pack.
- A normal release export uses the shared engine baseline. `--allow-engine-drift` is reserved for explicit compatibility or test artifacts and synchronizes a temporary legal bundle to the stable engine actually used. License and notice files are copied beside the executable or Web payload after the pack has been verified.
- Before a release candidate run `node tools/release_readiness.js`. Details: `docs/RELEASE.md`.

## Facts and procedures

| To decide | Read |
| --- | --- |
| Domain invariants: content, save compatibility, audio, travel, dialogue, licensed art | `.agents/rules/project-domain.md` |
| Release process, CI jobs, publishing | `docs/RELEASE.md`, then `.agents/prompts/recipes/release.md` |
| Engine and addon upgrade policy | `docs/ENGINE_UPGRADES.md`, then `.agents/skills/toolchain/SKILL.md` |
| Localization rules and the coverage gate | `docs/LOCALIZATION.md` |
| Audio routing and cue ids | `docs/AUDIO.md` |
| Licensed local art | `docs/LICENSED_ASSETS.md` |
| Diagnostics and support bundles | `docs/SUPPORT.md` |
| Automation levels, escalation to a person and the executable entry points of each area | `docs/AUTOMATION.md` |
| Third-party syntax, APIs, versions, or agent host guidance | `docs/OFFICIAL_DOCS.md`, then the official page that matches |
| The fixed release, engine upgrade, game QA, diagnostics and CI recipes of this repository | `.agents/prompts/agent-prompt-shortcuts.md`; open only the recipe that matches |

## Tool discovery

- Every tool is a script run as `node tools/<name>.js`; `node tools/validate.js` is the single local validation entry point. Flags and behaviour come from the script itself; read it rather than guessing from `--help` output.
- The engine used by a tool is `--godot-bin <path>`, else the `GODOT_BIN` environment variable, else `godot` on `PATH`. A result that depends on engine behaviour counts only when the engine matches `.godot-version`.
- Write-type commands, side effects, dependencies, Git and third-party authorization are judged by the matching boundary in `.agents/rules/project.md`.
