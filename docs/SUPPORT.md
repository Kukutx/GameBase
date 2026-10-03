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
- Godot engine version
- operating system name
- active locale
- save schema and active save slot
- in-game day/time
- stable Location ID when available

It intentionally does not record user account data, personal files, precise device identifiers, or absolute filesystem paths.

## When investigating a report

Ask for:

1. the newest `gamebase.log`;
2. the affected save slot files when the problem is save-specific;
3. the exact action that triggered the issue;
4. the Godot/GameBase build or Git revision used.

Search the log for `GAMEBASE_DIAGNOSTIC`, `ERROR:`, and `SCRIPT ERROR:` first.

## Save safety

Manual saves and autosaves share the same temporary-file, backup and atomic finalization path.

Autosave is enabled by default and:

- attempts a periodic save every 5 real minutes;
- attempts a save after successful world travel;
- skips unsafe states such as active travel, fishing, missing player, or unregistered scenes;
- suppresses normal success toasts;
- never overwrites a newer-format primary save with an older build.

Players can disable autosave in Settings.
