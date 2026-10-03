# GameBase

Godot 4.x life-sim / RPG foundation built from the Godot-GameTemplate repository and extended into a data-driven multi-town game prototype. The application version lives in `.game-version`; the independent shared engine-validation baseline lives in `.godot-version` (currently 4.7.2), so game releases and Godot upgrades can move independently.

The current project is a reusable gameplay base rather than a finished content release. The main playable loop already connects farming, fishing, mining/combat, animals, crafting/processing, NPC relationships, quests, weather/calendar systems, town progression, saving and world travel.

## Engine and addons

- GameBase application version: `.game-version` (mirrored to `application/config/version`)
- Godot **4.x**; current CI validation baseline: **4.7.2** via `.godot-version`
- Dialogue Manager **3.10.5**
- GUT **9.7.1** for automated tests
- Game-owned runtime layer; the inherited shooter/template addons are no longer production dependencies

Stable Godot 4.x upgrades are expected. Update the single `.godot-version` CI baseline, confirm addon compatibility, and run the full validation/export suite. Check `AGENTS.md` before framework or dependency changes.

## Run

Open this folder in a compatible stable Godot 4.x release and run the project. The current shared validation baseline is Godot 4.7.2. The main scene is:

```text
res://game/ui/title_screen.tscn
```

Full local validation:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate.ps1
```

The script uses `GODOT_BIN` when set, otherwise `godot` from `PATH`. It accepts newer stable Godot 4.x versions and warns when the local engine differs from the shared CI baseline.

A successful runtime integration check ends with:

```text
LIFE_SIMULATION_SMOKE_OK
```

## Current gameplay foundation

- Three connected settlements: Starter Town, Riverside Town and Harbor Town
- Player home and Old Mine interiors/areas
- Farming with seasonal crops, watering, harvests and sprinkler automation
- Fishing with location, season, time and weather-specific pools
- 120-floor Old Mine progression with persistent depth, 5-floor elevator checkpoints, Iron at Floor 6, Gold at Floor 20, Iridium at Floor 60, escalating enemy tiers through the Ancient Slimes on Floor 120, melee combat and renewable resource nodes
- Farm animals with housing, feeding, happiness, naming, selling, premium products and purchasable 4→8→12 slot coop/barn expansions
- Inventory, hotbar, shops, crafting, cooking, buffs, processing and copper→iron→gold→iridium tool/weapon upgrades
- Placeable storage, machines and persistent building placement
- Shipping bin and overnight economy settlement
- NPC schedules, cross-town movement, gifts, 0→10-heart relationship dialogue stages and five heart-event tiers per core NPC, with later events tied to town progress
- Dialogue abstraction plus bounded NPC memory/context for optional AI dialogue later
- A long mining quest chain from copper tools through Iron, Gold and Iridium to Floor 120, plus progression mail that can react immediately to completed quests and world flags
- A deterministic calendar/weather system with four recurring seasonal festivals, in-world participation booths and once-per-year rewards
- Daily contracts that filter mining targets by discovered mine depth, harvest work by crop maturation/season time remaining, and weather-locked fish by reachable forecast windows
- Chained long-term town restoration projects with world-state visuals, NPC-context exposure and immediate completion mail
- Six skills with Lv5/Lv10 passive gameplay perks and persisted highest-earned level entitlements, so later XP-threshold rebalance cannot take away an already-earned skill level/perk; collections include premium animal products and Iridium content with claimable archive milestones
- Three save slots with Save v8 migration, stable Location-ID recovery across scene renames, millisecond-aware primary/backup/temp crash recovery (including a newer complete temp written before primary removal), and protection for newer-version primary saves when an older build falls back to a compatible backup
- Stable world travel end-to-end: new game, scene portals, mine ladders/elevators and save recovery resolve Location/Spawn IDs instead of depending on gameplay scene filenames
- Long-lived save repair for content evolution: appended quest/project chains backfill on load; completed projects reapply current unlock flags; paid coop/barn capacity is preserved independently from expansion resource IDs; already-ready archive milestones remain qualified when catalogs grow; and removed crops/animals/placeables/contracts/processing content plus legacy inventory items degrade safely instead of blocking play or silently deleting player value
- Deferred rewards are snapshotted when promised (mail delivery, project completion, archive readiness and blocked quest completion), preserving the original money/items even if later content updates rebalance or retire reward entries
- Sleep, defeat/collapse recovery and late-night exhaustion handling
- Rebindable keyboard controls, D-Pad/analog movement, LT/RT hotbar cycling, device-aware interaction prompts and default gamepad bindings for all core actions
- Safe periodic/travel autosave using the same atomic backup path as manual saves; autosave can be disabled in Settings
- Persistent English / Simplified Chinese UI locale selection, with dialogue localization kept behind Dialogue Manager

## Project structure

```text
game/core/      Reusable gameplay services and components
game/data/      Data resources indexed through ContentDB
game/world/     Playable locations and shared world HUD
game/npc/       NPC scenes and presentation
game/player/    Player scene/controller
game/ui/        Title, pause, settings and game menus
test/unit/      Focused GUT regression tests
test/runtime/   End-to-end life-simulation smoke test
tools/          Local project utilities
docs/           Project-specific documentation
```

New reusable content should normally be added to `game/data/content_manifest.tres` and accessed through `ContentDB` rather than hard-coded lookup tables.

## Validation and release

The repository tracks `export_presets.cfg` for Windows, Linux and Web. Local exports:

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1
```

Preferred full pre-release verification:

```powershell
powershell -ExecutionPolicy Bypass -File tools/release_readiness.ps1
```

That command performs a clean import, the full test suite, all three exports, native exported-build smoke where supported, and a real Chromium smoke of the Web build.

GitHub Actions provides:

- `.github/workflows/ci.yml`: strict clean-import validation, GUT/runtime/main-scene smoke, Windows/Linux/Web exports, native Windows/Linux execution and Chromium Web smoke.
- `.github/workflows/release.yml`: gated Windows/Linux/Web packages, native/browser smoke, SHA-256 checksums, and automatic GitHub Release publishing for `v*` tags.
- `.github/workflows/engine-compat.yml`: weekly validation against the newest stable Godot 4.x release without silently moving the shared baseline.
- `.github/dependabot.yml`: weekly GitHub Actions and npm QA-tool dependency maintenance.

The game version and engine baseline are intentionally separate. Bump the application version with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/update_game_version.ps1 -Version <next-semver>
```

The engine version used by CI is read from `.godot-version`. To move the shared validation baseline to a newer stable Godot 4.x release:

```powershell
powershell -ExecutionPolicy Bypass -File tools/update_engine_baseline.ps1 -Version <next-stable-4.x-version>
```

Then validate with the new engine before committing the baseline change. See `docs/ENGINE_UPGRADES.md`, `docs/RELEASE.md`, `docs/LOCALIZATION.md`, and `docs/SUPPORT.md`.

## Licensed local art

Purchased/local source art is intentionally excluded from Git under:

```text
game/art/licensed/
```

On the owner's workstation, restore the selected runtime assets with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/sync_licensed_assets.ps1
```

See `docs/LICENSED_ASSETS.md` for the packs currently used and redistribution constraints. Gameplay scenes must remain runnable when those local files are absent; fallback visuals are part of the project design.

## Development rules

`AGENTS.md` is the source of truth for project constraints. In particular:

- keep the project on stable Godot 4.x and treat `.godot-version` as an updateable CI validation baseline rather than a permanent patch-version lock;
- prefer built-in Godot features and established, maintained addons;
- keep third-party code under `addons/` and game-specific code under `game/`;
- preserve stable content/location/spawn IDs and save compatibility;
- add focused GUT coverage for reusable gameplay systems;
- keep the optional AI dialogue layer behind `ConversationService`, `NpcContext` and `NpcMemory` rather than coupling gameplay to a model runtime.
