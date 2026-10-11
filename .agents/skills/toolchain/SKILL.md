---
name: toolchain
description: Check and upgrade the Godot engine baseline, the vendored addons and the Node line, or report what a newer version offers. Use for version drift between the local engine and CI, the weekly engine-compatibility or addon-freshness results, and upgrade requests; not for the package updates Dependabot proposes or for runtime diagnosis.
---

# Toolchain versions

Handles the versions this repository pins by hand: the shared Godot baseline, the two vendored addons and the Node line. Dependabot proposes the updates of the Playwright package of the Web smoke and of the GitHub Actions versions (`.github/dependabot.yml`); those are ordinary dependency changes. The policy and its reasons are in `docs/ENGINE_UPGRADES.md`.

## Collect the facts first

- Engine baseline: `.godot-version`, mirrored in `licenses/GODOT_VERSION.txt`. Feature marker: `config/features` in each `games/<id>/project.godot`. The engine a command really used is the `Godot:` line printed by `node tools/validate.js`.
- Addons: `version=` in `addons/dialogue_manager/plugin.cfg` and `addons/gut/plugin.cfg`. `node tools/check_addon_updates.js` compares them with upstream stable tags and writes `artifacts/addon-updates.md`.
- Node: the `node-version` of every workflow under `.github/workflows/` and `engines.node` in `tools/web_smoke/package.json`; they move together.
- Do not judge "latest" from memory. When an upstream query fails, report that; do not treat it as "already current".

## Engine baseline upgrade

1. Confirm that GUT, Dialogue Manager and any other enabled addon support the target stable release.
2. `node tools/update_engine_baseline.js --version <x.y.z>` downloads and validates the official LICENSE and COPYRIGHT of that tag and only then moves `.godot-version` and the legal bundle together. Do not edit those files by hand.
3. Import each game once with the new engine and review every change it makes to `games/<id>/project.godot`, scenes and resources. Saving with a newer engine rewrites file headers (`.agents/rules/scenes-resources.md`); keep that rewrite in its own commit.
4. `node tools/validate.js --godot-bin <new engine>` including the soak, then `node tools/export.js --all` for all three presets of every game. Install matching export templates with `node tools/install_export_templates.js`.
5. Read the official migration notes between the old and the new version and compare them with how this project uses the engine. Besides errors, look for things that stop working without an error: a renamed setting that silently falls back to a default, a deprecated call that still runs.
6. Report separately: new capabilities that would remove custom code, deprecated usages still present, behaviour changes that need a gameplay check.

Development, beta and release-candidate builds do not become the shared baseline unless the user asks for it. A newer stable engine may be used locally before the baseline moves; results that depend on engine behaviour are then reported with the engine that produced them.

## Addon upgrade

- Prefer the newest compatible patch or minor release that does not force unrelated gameplay migrations. A major upgrade is isolated, migration-tested and reversible.
- After replacing the vendored directory: check the release-export exclusions in each `games/<id>/export_presets.cfg` and the required and forbidden lists in `tools/verify_export_contents.js`, check the addon assertions in `tools/repository.test.js`, then run the full validation and all exports.
- The rules for touching `addons/` are in `.agents/rules/addons.md`.

## Only asking what is new

When the user does not upgrade and only asks what a newer version offers: find the versions with `node tools/check_addon_updates.js` and the official release pages, read the release notes between the installed and the newest version, and report the three groups from step 6 with the version and link each statement comes from.

## Boundaries

- Upgrades, downgrades and new dependencies need their own authorization. A version flag is not an authorization.
- Do not lower a pinned version, switch a stable version to a preview, delete a check or widen a version range to make a failing check pass.
- Write a target version only after confirming that it has been released and can be installed.
- "Completed" means the listed local steps passed. Compatibility artifacts built with `--allow-engine-drift` are not release candidates.
