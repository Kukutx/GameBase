# Project audit reference framework

Read this on demand only in a complex or whole-repository audit under `project-audit`. This file offers **optional dimensions of evidence and ways of collecting it**; it is not a fixed checklist, a scoring system or a source of project facts.

## 1. Fix the question that really has to be answered

- Start by default from the topic the user named; a scoped audit is not widened automatically into a whole-repository audit.
- Build a coverage list only when the user explicitly asks for a whole-repository, full, system-level or pre-release panorama audit.
- Target platforms, scale, stores and a time roadmap need confirming only when they would change the current conclusion; do not fill in default platforms or a long-term plan yourself.
- When any key area cannot be read, conclude only for the range that can be shown and state `Unknowns` explicitly; do not cover a gap in evidence with a score or with "no problems found".

## 2. Priority of evidence

Prefer the material closest to the source of truth that proves the problem most directly:

1. Current source code, data contracts, the save schema, migrations, configuration, the content packs and the inputs of generated output.
2. The direct call chain, consumers and related tests.
3. Read-only runtime evidence: logs, state, traces, tool output.
4. The current fact documents the Profile names.
5. Current official documentation, support matrices, lifecycle / end-of-life notices or migration guides (only when a third-party capability, a version or platform behaviour is really relevant).
6. Historical reports, archives and old plans are leads only; go back to the current implementation and verify again before a judgement that leads to action.

For each finding answer at least:

- **Symptom**: exactly what behaviour or inconsistency exists?
- **Trigger condition**: under what circumstances does it happen?
- **Impact**: which players, data, saved progress, stability, release work or maintenance cost does it affect?
- **Evidence**: which current materials prove it?
- **Counter-evidence**: is there already validation, a migration, an idempotent path, a test, a gate or another protection?
- **Root cause**: is it a local implementation, state ownership, the single source of truth, an architecture boundary, external configuration, or the requirement or design model?
- **Strength of conclusion**: fact / inference / to be verified.

A TODO, complex code, a missing test, a dependency version, the number of files or code style is not a defect by itself, unless a concrete effect can be shown.

## 3. Audit evolution and versions only when relevant

Do not apply `greenfield / maintained` mechanically to every module. Check the following only when the current question involves compatibility, migration, a choice of version, data evolution or a support obligation:

- Does the current scope really have published consumers, persisted data, an external interface or protocol, or a long-term support obligation?
- Does the project's default evolution strategy agree with the facts of this scope? When it does not, the real facts decide.
- Did a new scope wrongly copy an old template version, an ownerless compatibility layer, a double read or double write, a shim or a long-lived fallback?
- Did a maintained scope ignore real consumers, data migration, the support period, end of life, security risk and an observable rollout?
- "A newer version exists" is not a reason to upgrade by itself, and "an old version" is not a problem by itself, unless support, security, compatibility or maintenance facts show that action is needed.

## 4. Use severity only when it helps

Not every audit needs scores. When risks have to be ordered, this may be used:

- **P0**: confirmed or near-certain serious unauthorized access, exposure of sensitive data or of licensed assets, loss or corruption of saves, unrecoverable data loss, or the core chain being completely unusable.
- **P1**: a high probability that a core flow fails, a major error in saved state or player progress, or a security or stability risk that can clearly grow.
- **P2**: an important but bounded reliability, performance, maintainability, experience or consistency problem.
- **P3**: a low-impact improvement or clear technical debt.

A high-risk suspicion without enough evidence goes into `Unknowns / to be verified`; severity is not raised on imagined risk alone. Do not score every dimension for a complete matrix, and do not produce a fixed top N.

## 5. Choose audit dimensions by the question

This is a menu of evidence, not something to cover completely every time.

### Security / permissions / data

Authentication and authorization where an online service is involved, ownership of objects, input from outside the game (save files, configuration files, imported data), uploads and downloads, redaction of logs and diagnostic bundles, secrets, retention, deletion and export of data, and the trust boundary with third parties (addons, CI actions, release channels).

### Game rules and state consistency

State machines, roles, eligibility, cancel / fail / retry, re-entrancy, idempotence, the atomicity of a save, and whether documentation, data contracts and consumers agree in meaning. The facts of a specific domain — states, the save format, the economy, progress — are confirmed in the nearest current source of truth of the project; this framework keeps no copy of a state machine.

### Data contracts and consumers

Whether the save schema and its migrations, stable content ids and the content packs, exported resource fields, autoload interfaces and their direct consumers are synchronized; whether a second source of truth, hand-written compatibility or a half-finished migration has appeared.

### Stability and bugs

Error boundaries, empty collections, paging and long lists, in-game dates and time, amounts and numeric precision, races and frame-order dependence, retries, failure of external calls and file access, stale caches, partial failure of batch work, and recovery paths.

### Performance

Repeated lookups inside loops, unbounded queries over all content, per-frame work, memory-heavy batch work, loading hitches, node and draw load, and the load of lists, images and maps in the UI. A static signal only forms a risk hypothesis; real performance needs matching measured evidence.

### UX / accessibility

Check only what relates to the audit scope: loading / empty / error / unavailable states, repeated submission, long text, both languages, keyboard and gamepad input, scaling of the base viewport, focus, the accessibility settings the game exposes, and feedback for dangerous actions. Without visual or runtime evidence, do not claim that visual quality was verified.

### Tests / observability / operations

Regression for key failure paths, error logging, traces, diagnostic bundles, the source of truth of configuration, isolation between a local run and an exported build, boot and smoke checks, recovery and runbooks, and CI gates.

### Documentation and agent rules

Whether a current fact has a single source of truth; whether a formal page mixes in process, an old model or a snapshot of live state; whether the layers of rules are clear; whether the generic layer leaks this project's paths, versions, commands or game facts; whether a project overlay lost necessary executable information for the sake of being "generic".

## 6. Coverage method for a full audit

Use this when the user asks for a full audit of a named scope or of the whole repository; the coverage list is always bounded by that scope:

- List the first-level areas and the key game chains that must be covered; record `read / sampled / excluded / unreadable`.
- Exclude dependency directories, build caches, binaries and the body of vendored third-party code; trace generated output back to its input.
- For `.env*`, secrets and sensitive runtime data, check only safe existence and reference chains; do not read or copy the values.
- For a cross-domain chain that really is key, check the entry point, authorization and state, persistence and external side effects, consumers, failure / retry / concurrency, and regression evidence.
- Stop when the evidence is enough to answer the audit goal; do not keep producing low-value scans for the sake of being "complete".

Commands are for locating only; a finding is formed only after reading the context and the counter-evidence.

## 7. Re-audit

- An old report only supplies historical problems and confirmed constraints; it does not replace the facts of the current code.
- Collect evidence again for a problem that is still relevant; say "resolved / no longer reproduced" only when the current trigger path, the root cause and the regression evidence all support it.
- When a change in the code makes an old recommendation no longer apply, keep the original goal and judge the smallest correct repair path again.

## 8. Output principles

Prefer by default:

`Conclusion -> Findings -> Evidence -> Unknowns -> Priorities`

For a full audit of a named scope or of the whole repository, state the coverage and the status of every problem that holds; when domains are crossed, add the cross-domain risks. Scores, a platform matrix or a long-term roadmap are added only when the user needs them and are not a condition for completing the audit.
