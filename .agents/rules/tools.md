---
path: tools/**
---

# Tools (`tools/**`)

## P0

- Tool scripts use Node; do not add Python, PowerShell or scripts in another language under `tools/`.
- Every tool is one plain Node 24 script run as `node tools/<name>.js [options]`. There is no tool registry, no package-manager wrapper and no categories; one capability has one script, and no historical alias or second entry point (a wrapper script, a package `scripts` entry or a `bin`) is kept for it. `tools/web_smoke/` is the only tool with its own `tools/web_smoke/package.json`, and it is run as `npm run --prefix tools/web_smoke smoke:web`.
- Know the largest side effect of a tool before running it, from its source: none, a local write (generated output, the import cache, the version files, the legal bundle) or an external write (GitHub issues, releases, tags, uploads). There is no read-only switch, so a read-only task runs only a tool, with only the options, whose source confirms that it writes nothing the task must not change; do not understate a side effect in order to run something inside a read-only task.
- Build output, structured reports, logs, temporary JSON, screenshots and diagnostic output go to `build/`, `dist/` and `artifacts/`, which are all Git-ignored; do not put a temporary report in the root of `tools/` and do not commit one.
- `build/`, `dist/` and `artifacts/` are a **fully disposable temporary and evidence area** and may be deleted whole; no unique fact that a build, a release, signing or the running game needs in order to keep working may exist only there. Long-lived non-sensitive identity and configuration belongs in tracked files (`export_presets.cfg`, `.godot-version`, `.game-version`); long-lived keys, signing material and credentials belong in the protected repository or environment secret store and never in the repository. A report from a bootstrap step means "to be moved" until it is promoted, and does not become a second source of truth.
- Exported builds, packages, manifests and checksums, smoke logs, screenshots, browser diagnostics, test reports and old candidate or status snapshots are evidence that can be rebuilt or read back, and by default are not promoted to tracked sources or secrets. When the user explicitly wants a long-term local copy, it goes to a Git-ignored location, and neither the running game nor the release tools may depend on it.
- A tool that touches GitHub issues, releases, tags, repository settings or uploads defaults to read-only or a dry run; a write needs an explicit target, an explicit action and the user's authorization.
- Do not assume that `--help` or a trial run of a writing tool has no side effect (`export`, `package_release`, `generate_release_manifest`, `release_readiness`, `update_engine_baseline`, `update_game_version`, `validate --clean-import`); first read the implementation to see how its arguments are handled, and do not run it without the matching write authorization.
- A tool does not print secret values; arguments, logs, reports and error output mask tokens, passwords, secrets, private keys and similar sensitive values.
- Do not add a second entry point for validation, export, packaging, the release manifest, the version bump, the engine baseline update or cleanup; reuse the existing scripts and `tools/lib/` first.
- Do not edit by hand what a tool generates: the Godot legal bundle under `licenses/`, the application version in `.game-version` and `project.godot`, `BUILD_INFO.json`, `RELEASE_MANIFEST.json` and `SHA256SUMS.txt` are produced only by their tools.

## P1

- Tools run the same on Windows and Linux. Child processes are started only through `tools/lib/common.js` (`run`, `runGodotStep`, `git`, `npmCommand`), which owns process running, the detection of Godot error lines and the one place where a shell is used (`npmCommand`, because npm is a `.cmd` shim on Windows); do not build a `cmd.exe` line yourself and do not pass `shell: true` anywhere else. A tool that needs a secret takes it from the environment and writes it to no argument, log or report.
- Human-readable output is plain console text; errors are raised with `fail` or `ToolError` and a script body runs inside `main` from `tools/lib/common.js`, without adding a colour or logging dependency. Paths, file reads and writes, Git calls and downloads reuse `tools/lib/common.js` first; deterministic ZIP and tar.gz writing and reading reuse `tools/lib/archive.js`.
- A new tool rejects unknown options before it does anything, and a `--help` it offers has truly no side effect; a tool that can write outside the generated directories, delete, reset, publish or change external configuration provides a preview or dry run or an explicit confirmation gate, with a test that asking for help does not run the default action by accident.
- Git hooks do only fast deterministic checks on staged files; a `pre-commit` hook must not start a Godot import, the GUT tests, the soak, an export, a dependency install or audit, or a network check.
- When adding or changing CI/CD, a build or test runner, release orchestration or an automated gate, read `.agents/rules/ci-performance.md`; the time budget, triggering by impact, reuse of equivalent evidence, test layering, controlled parallelism, scan frequency and the cache and cleanup boundaries are all maintained by that rule, and the tool layer does not set up a policy of its own.
- A tool's options, its examples and the documentation are closed up together: the script, the commands in `AGENTS.md`, `README.md` and `docs/RELEASE.md`, the workflows that call it and the assertions about them in `test/unit/test_project_configuration.gd` stay consistent.
- Output meant for automation stays machine-readable; status, hints for people and debug information are not mixed into the data that a caller parses, and a failure ends with a non-zero exit code and a message on the error stream.
- A tool entry validates its input, gives a clear error, sets a timeout or an interruptible boundary for a long task, and cleans up the temporary resources it created.
- There is no cleanup tool. Generated output is cleared by deleting the contents of `build/`, `dist/` and `artifacts/` while keeping their `.gdignore` files, and `node tools/validate.js --clean-import` is the path that removes the `.godot/` import cache; do not add a second cleanup entry and do not let a tool delete outside these places.
- When changing a shared tool — validation, export, packaging, the release manifest, the localization check, `tools/lib/` — add the smallest regression check first: a `tools/<name>.test.js` file run with Node's built-in test runner, the packaging self-test, or `test/unit/test_project_configuration.gd`.

## P2

- Keep the flat `tools/<name>.js` layout with shared code in `tools/lib/`; a new subdirectory must first show that the flat layout cannot express it.
- Tool names and options use the current meaning in the project; a rename synchronizes every reference and keeps no compatibility alias.
- An error message gives a next step that can be carried out; errors are not swallowed to look like success.

## Documents and commands

- `docs/RELEASE.md`
- `docs/ENGINE_UPGRADES.md`

```
node tools/validate.js [--skip-soak] [--skip-import] [--clean-import] [--godot-bin <path>]
node tools/validate_rules.js --strict [--report]
node --test "tools/*.test.js"
node tools/check_localization.js
node tools/export.js [--preset "Windows Desktop"|Linux|Web] [--skip-validation] [--allow-engine-drift]
node tools/smoke_export.js
node tools/release_readiness.js
node tools/package_release.js
node tools/generate_release_manifest.js
node tools/update_engine_baseline.js --version <x.y.z>
node tools/update_game_version.js --version <semver>
node tools/check_addon_updates.js
npm run --prefix tools/web_smoke smoke:web
```
