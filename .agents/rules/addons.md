---
path: "addons/**"
---

# Vendored addons (`addons/**`)

## P0

- Third-party addon code stays under `addons/`; game-owned code stays under `game/`. Do not mix gameplay-specific logic into a vendored addon unless it fixes a verified upstream compatibility bug, and say so in the change.
- The approved infrastructure addons are **Dialogue Manager 4.1.0** for authored branching dialogue and **GUT 9.7.1** for tests. Adding, removing, upgrading or downgrading an addon is a dependency change and needs its own authorization (`.agents/rules/project.md`).
- Addon sources stay byte-for-byte close to upstream, including whitespace an upstream release carries. Do not reformat, lint or "clean up" files under `addons/`.
- `.github/workflows/addon-freshness.yml` and `tools/check_addon_updates.js` compare the vendored versions with upstream stable tags every week. They may open or update a maintenance issue; they never replace vendored addon code. Upgrade an addon explicitly, isolate a major migration behind a clean Git baseline, and run the full validation and export suite.

## P1

- Dialogue Manager 4 uses cues (`first_cue`, `cues`) and the `dialogue` translation context for authored lines and responses.
- Release exports intentionally exclude only the addon's editor and debugger assets, components, views and plugin tooling. Its runtime compiler, settings, default balloon, runtime l10n, test-scene dependency and the required `nodes/` runtime controls stay in the pack unless the upstream runtime dependencies are audited again; `tools/verify_export_contents.js` lists what must and must not be present.
- GUT is a test-only addon and is excluded from every release pack.
- Before proposing a new addon, check the criteria in `.agents/rules/project-profile.md` and whether built-in Godot capabilities already solve the problem.

## Verification

- `node tools/check_addon_updates.js` reports the installed and the newest stable upstream version of each addon.
- After an addon change: `node tools/validate.js`, then `node tools/export.js` for all three presets.
