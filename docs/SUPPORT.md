# Support and diagnostics

GameBase keeps release diagnostics intentionally small and local.

## Runtime logs

Desktop builds use Godot file logging with:

- log path: `user://logs/<id>.log`, for example `user://logs/farm1.log`
- retained logs: 5
- GDScript call stacks enabled in release builds

Typical host locations:

- Windows: `%APPDATA%\Godot\app_userdata\<Game Name>\logs\`
- Linux: `$XDG_DATA_HOME/godot/app_userdata/<Game Name>/logs/`, usually `~/.local/share/godot/app_userdata/<Game Name>/logs/`

The Web build uses the browser console instead of desktop file logging.

## Diagnostic context

`GameDiagnostics` writes `GAMEBASE_DIAGNOSTIC` JSON lines at startup and when a save (an autosave included), a load or a travel fails.

The diagnostic payload contains only technical game context:

- diagnostic schema version
- game application version
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
- up to five recent game logs, capped at 2 MiB each;
- a README describing the bundle contents.

Before logs are packaged, known user-data, project, executable and home-directory absolute paths are replaced with placeholders. The bundle never includes raw slot files (`user://saves/slot_<n>.json/.tmp/.bak`), `settings.json`, local purchased source art, account credentials, or device identifiers. Web builds use browser-console diagnostics instead and do not expose filesystem support bundles.

## When investigating a report

Ask for:

1. the player-created support bundle when available, or the newest `<id>.log` otherwise;
2. the adjacent release `BUILD_INFO.json` when available;
3. the affected raw save slot files only when the problem is specifically save-related and the player chooses to share them;
4. the exact action that triggered the issue.

`BUILD_INFO.json` identifies the game and its version, exact Git commit, actual Godot engine used for the export, whether the source tree was dirty, and the target platform.

Search the log for `GAMEBASE_DIAGNOSTIC`, `ERROR:`, and `SCRIPT ERROR:` first.

## Save provenance and safety

Save snapshots record both `game_version` and `engine_version` at the top level, and slot summaries expose them.

The numeric save `version` field is the save-format version and is independent from the game version in `config/version` of `games/<id>/project.godot`. Only a save of the current format loads; there are no migrations. A slot whose files this build cannot read is shown as such on the title screen, and a new game asks before replacing it.

Manual saves and autosaves share one path: the new save is written to a temporary file, the previous save is renamed to the backup, and the temporary file then replaces the save. A write interrupted at any point leaves an intact file of the three, and loading takes the newest one.

Nothing saves while a save loads, a new game starts, or the player travels.

Autosave is enabled by default and:

- attempts a periodic save every 5 real minutes;
- attempts a save after successful world travel;
- attempts a save when the window closes;
- skips unsafe states such as active travel, fishing, missing player, or unregistered scenes;
- shows "Autosaved" for a moment on the HUD (`SaveIndicator`) when it saved, instead of a toast;
- tells the player why with a toast when the save could not be written. The log has a `WARNING:` line naming the file and an `autosave_failed` diagnostic.

Players can disable autosave in Settings.
