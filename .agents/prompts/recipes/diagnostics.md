# Build identity, logs and runtime diagnostics recipe

Read only for the state of a running or exported game, its logs and diagnostic context, a support bundle, a save-slot summary, or the diagnosis of a player report. By default gather evidence read-only; publishing a release, moving a tag, replacing published packages, changing or deleting a player's save, a save migration, and a write to repository settings or a third party are still decided by the current request.

## Read-only checks of the build and the environment

Use the entry points the project already has. The local identity is read from `config/version` in `games/<id>/project.godot`, `.godot-version` and the engine binary; the project's validation prints it:

```
node tools/validate.js --skip-soak
```

It prints the `Godot:` line and the name and version of each game, and warns when the local engine differs from the baseline, but it also imports each game and runs the tests, so it is not run for the identity alone. A result that depends on engine behaviour counts only when the engine matches `.godot-version`.

For a build that is running or was published, prefer its own identity and the read-only state, and confirm only what the current problem needs:

- the game version in `config/version` of `games/<id>/project.godot`, and the engine baseline in `.godot-version`;
- the `BUILD_INFO.json` beside the exported build: the game and its version, exact Git commit, the Godot engine actually used, whether the source tree was dirty, and the target platform;
- which secrets and settings a workflow expects, whether they exist and how they are injected;
- the state of the workflow run that produced the build, and of the published release and its packages;
- the key errors, the version and the diagnostic lines in the log.

Do not print secret values, and do not change repository settings, a workflow, a release or a tag as part of a diagnosis.

## Logs and diagnostic context

A desktop build writes its log to `user://logs/<id>.log` and keeps five; the Web export uses the browser console instead and has no log file. `GameDiagnostics` writes `GAMEBASE_DIAGNOSTIC` JSON lines at startup and when a save, a load or a travel fails. Search a log in this order:

```
GAMEBASE_DIAGNOSTIC
ERROR:
SCRIPT ERROR:
```

A Godot step fails on a non-zero exit code or on any `ERROR:` or `SCRIPT ERROR:` output line, so a log is read for those lines even when the process ended with code 0. The smoke runs keep their own evidence: `node tools/smoke_export.js` writes the log of the exported build under `artifacts/<id>/release-smoke/`, and `npm run --prefix tools/web_smoke smoke:web` writes screenshots under `artifacts/<id>/web-smoke/` and prints the console, page and network errors.

Ask for more only when the current problem needs deeper runtime evidence, in this order: the support bundle the player created with the `SupportBundle` service when one is available, otherwise the newest `<id>.log`; the `BUILD_INFO.json` of the build; the exact action that triggered the problem; and the raw save files only when the problem is specifically about saving and the player chooses to share them. The bundle is opt-in and holds a whitelisted runtime and settings summary, summaries of the save slots without the raw save payloads, the recent logs with known absolute paths replaced by placeholders, and a README; `docs/SUPPORT.md` is the source of truth for its contents.

Write a report under `artifacts/` only when the user asks for one to be saved. The output separates the state of each source, the key suspects, the next actions and the unverified items. A raw save, `settings.cfg`, an absolute user path, a user name or a device identifier is never copied into a report, an issue, a commit or a message; a save is represented by its slot summary. Do not add telemetry, remote logging, a crash upload or a wider diagnostic payload for the sake of a diagnosis.

## Diagnosing a player report

Operating the game to reproduce a problem and the evidence that goes with it follow `.agents/skills/game-qa/SKILL.md`. By problem area, read only the owning service, the log and diagnostic lines, the current fact documentation and the necessary read-only state of the release; "deal with it if necessary" is not authorization to change a player's save, to publish a fix or to write to published state.

At the end give the conclusion, the factual evidence, the inferences and unverified items, and any new action that really needs authorization; a normal state does not produce a checklist for a person to review.
