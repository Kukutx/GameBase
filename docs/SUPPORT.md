# Support and diagnostics

GameBase keeps release diagnostics intentionally small and local.

## Runtime logs

Desktop builds use Godot file logging with:

- log path: `user://logs/gamebase.log`
- retained logs: 5
- GDScript call stacks enabled in release builds

Typical host locations:

- Windows: `%APPDATA%\Godot\app_userdata\GameBase\logs\`
- Linux: `$XDG_DATA_HOME/godot/app_userdata/GameBase/logs/`, usually `~/.local/share/godot/app_userdata/GameBase/logs/`

The Web build uses the browser console instead of desktop file logging.

## Diagnostic context

`GameDiagnostics` writes `GAMEBASE_DIAGNOSTIC` JSON lines at startup and when save/load/travel operations fail.

The diagnostic payload contains only technical game context:

- diagnostic schema version
- GameBase application version
- Godot engine version
- operating system name
- active locale
- save schema and active save slot
- in-game day/time
- stable Location ID when available

It intentionally does not record user account data, personal files, precise device identifiers, or absolute filesystem paths.

## Player-created support bundle

Desktop builds expose **Settings → Accessibility → Export Support Bundle**. The game writes a ZIP under `user://support/` and the adjacent **Open Support Folder** button opens that directory.

The bundle is opt-in and contains:

- a whitelisted runtime/settings summary;
- summaries for all three save slots, without raw save payloads;
- up to five recent GameBase logs, capped at 2 MiB each;
- a README describing the bundle contents.

Before logs are packaged, known user-data, project, executable and home-directory absolute paths are replaced with placeholders. The bundle never includes raw `savegame*.json/.tmp/.bak`, `settings.cfg`, local purchased source art, account credentials, or device identifiers. Web builds use browser-console diagnostics instead and do not expose filesystem support bundles.

## When investigating a report

Ask for:

1. the player-created support bundle when available, or the newest `gamebase.log` otherwise;
2. the adjacent release `BUILD_INFO.json` when available;
3. the affected raw save slot files only when the problem is specifically save-related and the player chooses to share them;
4. the exact action that triggered the issue.

`BUILD_INFO.json` identifies the GameBase version, exact Git commit, actual Godot engine used for the export, whether the source tree was dirty, and the target platform.

Search the log for `GAMEBASE_DIAGNOSTIC`, `ERROR:`, and `SCRIPT ERROR:` first.

## Save provenance and safety

Save snapshots record both `game_version` and `engine_version` at the top level, and slot summaries expose them.

The numeric save `version` field is the save-format version and is independent from `.game-version`. Only a save of the current format loads; there are no migrations.

Manual saves and autosaves share the same temporary-file, backup and atomic finalization path.

Autosave is enabled by default and:

- attempts a periodic save every 5 real minutes;
- attempts a save after successful world travel;
- skips unsafe states such as active travel, fishing, missing player, or unregistered scenes;
- suppresses normal success toasts;
- never overwrites a newer-format primary save with an older build.

Players can disable autosave in Settings.
