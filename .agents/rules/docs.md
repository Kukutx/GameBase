---
path: docs/**
---

# Docs (`docs/**`)

## P0

- **Where project facts live**: current project facts are written only in the formal pages `docs/*.md` and in `README.md`. The repository has no documentation site, generator or navigation configuration.
- **Plans and history are not the current source of truth**: future plans, history, abandoned decisions and other non-current material, wherever they are kept (roadmap notes, old plans, closed issues, commit history), cannot prove the current implementation on their own. A fact, a rule or an executable entry point that is still valid must be checkable in the code, the schemas, the configuration or a formal `docs/` page.
- **Formal pages state only current facts**: a formal `docs/` page keeps only current facts, rules in force and executable entry points that the sources of truth confirm; discussion of the process, the editing process, temporary states and non-current material are not written into a formal page.
- **The session is not a source for documentation**: the user's words, discussion of the process, reasoning, status updates, temporary plans and unconfirmed judgments are not written to disk because they "were discussed". Only a current fact or a rule in force that the sources of truth confirm, or a final conclusion the user explicitly asked to have recorded, is written to the page whose job matches.
- **Documentation is not a second source of truth**: when documentation conflicts with the code, the schemas, the configuration or the published state, check the matching source of truth first and then synchronize the documentation; do not let the documentation override the real implementation.
- **Agent rules are not written into game documentation**: the Agent reading order, path rules, the gates on commits, rollbacks and dependencies, and execution workflows live in `.agents/` and are not copied into `docs/`.
- **Schema and release facts are not changed in documentation alone**: a change to the save schema, content ids, exported resource fields, input actions, export presets, the version files, or release and CI behaviour goes back to the matching source of truth; when the user's scope does not allow the required synchronization, state the blocker first.
- **Generated text is not edited by hand**: the Godot legal bundle under `licenses/` is written by `node tools/update_engine_baseline.js`, the application version in `.game-version` and `project.godot` by `node tools/update_game_version.js`, and `BUILD_INFO.json`, `RELEASE_MANIFEST.json` and `SHA256SUMS.txt` by the export and release tools; they are maintained through those tools only.
- **A documentation task does not widen authorization**: correcting documentation does not authorize adding a dependency, setting up a documentation site or build, changing the release configuration, or publishing anything.
- **Language**: documentation is written in English; field names, code identifiers, third-party product names, protocol names and commands stay as they are, and Simplified Chinese appears only where a page quotes player-visible text.

## P1

- An entry document lets the reader quickly confirm the current job, where the source of truth is and what the executable entry point is; its length follows from the information needed for that purpose, and boundaries, exceptions or non-obvious constraints that would change the result of execution are not deleted for the sake of brevity.
- `README.md` and the fact table in `.agents/rules/project-profile.md` are **navigation by task**, not "read all of it".
- When tidying documentation, first delete repeated Agent constraints, outdated passages and duplicate indexes; game rules, schemas, operating instructions and commitments to players stay on the current fact page closest to them.
- In `docs/`, "must / do not / never" stay only where they describe gameplay, safety, operation, platform limits or commitments to players; general Agent behaviour goes back to `.agents/`.
- Synchronize the references to a page (`README.md`, `AGENTS.md`, other pages) only when a page is added, moved or deleted; an ordinary edit of the body creates no navigation churn.
- Refer to files by repository-relative path; write a new command as `node tools/<name>.js …` so that it runs the same on Windows and Linux; do not hard-code a count that a tool can compute or a version number that drifts easily.
- When third-party syntax or an API is uncertain, look it up through `docs/OFFICIAL_DOCS.md` in the official documentation of the engine, the addon or the platform for the version in use; what a source of truth of the project already settles is not looked up again.
- Wording about licenses, third-party notices, licensed assets, and what diagnostics and support bundles record is adjusted only within the scope the user authorized; if a change would alter a real commitment or a real flow, judge by `.agents/rules/project.md` whether the current request already gives explicit, informed authorization, and state the impact and confirm only when it does not; do not confirm a second time mechanically.
- Images, logos, screenshots and design assets are handled by the visual asset protection rules; nothing from `game/art/licensed/` is copied into `docs/`.
- A thorough documentation pass first separates current facts, operating instructions, indexes and historical material, and checks each class for the source of its facts, the side effects of its commands, duplicated jobs and links. A link scan and a rule scan prove only the static conditions they cover; they do not prove that the gameplay, the published state or the whole body is correct. Facts that are still valid are not bulk-rewritten because the model changed.

## P2

- When one topic entry can explain the matter, do not add a general index page.
- Delete only empty shells, duplicate indexes or outdated content inside the current scope that can be shown to be useless.
- Headings, tables and lists are there to be scanned; do not copy implementation detail into a second long text.

## Documents and commands

- `docs/RELEASE.md`
- `docs/LOCALIZATION.md`
- `docs/AUDIO.md`
- `docs/ENGINE_UPGRADES.md`
- `docs/LICENSED_ASSETS.md`
- `docs/SUPPORT.md`
- `docs/AUTOMATION.md`
- `docs/OFFICIAL_DOCS.md`

There is no documentation build. A page that states a command, a path or a behaviour is checked against the tool or file it names:

```
git diff --check
node tools/validate_rules.js --strict
node tools/validate.js
```

`node tools/validate_rules.js --strict` is the Agent rules check and matters when a page is referenced from `AGENTS.md` or `.agents/`; `node tools/validate.js` is needed only when the documentation change accompanies a change it verifies.
