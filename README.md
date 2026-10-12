# GameBase

GameBase is the single repository for a family of Godot 4.x games: a shared, genre-agnostic foundation and every game built on it, side by side. A fix to the foundation reaches every game in the same commit; there is no second repository, no copied foundation and no version pin to move.

## Layout

```text
gamebase/core/        Genre-agnostic foundation services (save, content, session, rules, settings,
                      input, audio, world travel, time, randomness, stats, profile, interactions,
                      minigames, diagnostics, and the title, pause and settings menus)
gamebase/modules/     Optional gameplay modules: items, skills, combat, lifesim, npc_social, npc_ai, progression, roguelite, rts, tactics
gamebase/templates/   The template tools/new_game.js creates a game from
gamebase/gamebase.json  The core's autoloads, the modules with the modules each one requires and the
                      addons and autoloads each one uses, and the addons every game links
addons/               Vendored third-party Godot addons shared by every game (Dialogue Manager, GUT)
games/<id>/           One Godot project per game: game.json, project.godot, export_presets.cfg,
                      game/ (the game's own code and data) and test/ (GUT and runtime checks)
tools/                Node tooling: links, validation, export, packaging, release checks
docs/                 Project documentation (writing a module, release, localization, audio, support,
                      engine upgrades, automation policy) and the generated reference pages
AGENTS.md, .agents/   Agent instructions: rules, skills, workflows, standards and templates
```

The registered games:

| Game | Directory | Description |
| --- | --- | --- |
| Farm1 | `games/farm1/` | The first-generation farming life-sim; see [games/farm1/README.md](games/farm1/README.md) |
| Ember Depths | `games/dungeon1/` | A dungeon delve on the core, items, skills and combat; see [games/dungeon1/README.md](games/dungeon1/README.md) |
| Iron Banners | `games/strategy1/` | Strategy battles on a grid in active time and in real time on an open field, on the core, damage, rts and tactics; see [games/strategy1/README.md](games/strategy1/README.md) |

A game is registered by its `games/<id>/game.json`, which lists the foundation modules it uses (with every module they require) and any extra shared addons. Inside a game project, `res://game/` is that game's code, `res://gamebase/` the foundation and `res://addons/` the addons. Dependencies point one way: a game may use the core and its listed modules, a module may use the core and the modules it declares, and the core uses neither; `tools/check_layers.js` enforces this. See [gamebase/README.md](gamebase/README.md).

## Set up and run

A Godot project only sees files inside its own directory, so the foundation and the addons are linked into each game (junctions on Windows, symbolic links elsewhere; Git ignores them). After cloning, and after changing a game's modules:

```text
node tools/link.js
```

Then open `games/<id>/project.godot` in a stable Godot 4.x editor. The shared engine baseline is `.godot-version` (currently 4.7.2); newer stable 4.x releases are allowed locally. The tooling needs Node.js 24 or newer and has no other dependency; tools use `--godot-bin <path>`, else `GODOT_BIN`, else `godot` from `PATH`.

Create a new game, a small one that plays on the core alone (no module), with:

```text
node tools/new_game.js --id <id> --name "<Game Name>" [--description "<One line>"]
```

## Validation and release

```text
node tools/validate.js
```

runs the repository checks once (agent rules, layer dependencies, code guardrails, each game's project settings against its manifests, the reference pages, tool tests, the engine baseline and its legal bundle, the packaging self-test, and a game freshly created from the template) and then every game's checks (links, version, localization coverage, headless import, GUT, its runtime scripts and a main-scene boot). `--game <id>` limits the games; `--no-repository` and `--no-games` skip one half; `--clean-import` imports from an empty cache, `--skip-import` and `--skip-soak` skip those steps. `--test <script>` runs one GUT script and nothing else in each selected game that runs it (`node tools/validate.js --test test_save_slots --game farm1`); where a module and the game both have a script of that name it names them and takes the `res://` path of one instead. `--unit <name>` keeps only the script's tests whose names contain `<name>`.

Tools that act on one game take `--game <id>` or `GAMEBASE_GAME`, which they need now that more than one game is registered:

```text
node tools/export.js [--game <id>] [--preset "<name>"]
node tools/release_readiness.js [--game <id>]
node tools/update_game_version.js [--game <id>] --version <next-semver>
```

Builds go to `build/<id>/<platform>/`, packages to `dist/<id>/` and QA output to `artifacts/<id>/`. A game's version lives only in `config/version` of its `project.godot`; the engine baseline moves separately with `node tools/update_engine_baseline.js --version <x.y.z>`, which also refreshes the official Godot LICENSE/COPYRIGHT bundle.

GitHub Actions:

- `.github/workflows/ci.yml`: repository checks and per-game clean-import validation side by side, then Windows/Linux/Web exports, native Windows/Linux execution and Chromium Web smoke, judged by one `CI result` check. A pull request that changes only some games' own directories validates only those games, and one that changes only documentation runs the repository checks alone.
- `.github/workflows/release.yml`: a `game/<id>/v<version>` tag builds that game's deterministic Windows/Linux/Web packages, smokes them, writes `RELEASE_MANIFEST.json` and SHA-256 checksums and publishes a GitHub Release whose notes list that game's changes and its foundation's since its previous release.
- `.github/workflows/engine-compat.yml`: weekly validation and exports of every game against the newest stable Godot 4.x release, without moving the shared baseline.
- `.github/workflows/addon-freshness.yml`: weekly stable-tag comparison for the vendored addons; it maintains one reminder issue and never replaces addon code.

See `docs/MODULES.md` (writing a module), `docs/RELEASE.md`, `docs/ENGINE_UPGRADES.md`, `docs/LOCALIZATION.md`, `docs/AUDIO.md`, `docs/SUPPORT.md` and the reference pages `docs/reference/autoloads.md`, `docs/reference/events.md` and `docs/reference/rules.md`, which `node tools/generate_reference.js` writes from the code.

## Development rules

`AGENTS.md` is the entry point of the project constraints; it routes to the rules, skills and workflows under `.agents/`. `node tools/validate_rules.js --strict` checks that tree and runs as part of `node tools/validate.js`. In particular:

- everything lives in this repository: a new game is a new `games/<id>/`, never a new repository, and a foundation change is made once in `gamebase/`;
- keep the projects on stable Godot 4.x and treat `.godot-version` as an updateable CI baseline rather than a permanent patch-version lock;
- prefer built-in Godot features and established, maintained addons, kept under `addons/`;
- preserve stable content, location and spawn ids; a save format change raises `SAVE_VERSION` instead of adding compatibility code;
- add focused GUT coverage for reusable gameplay systems.
