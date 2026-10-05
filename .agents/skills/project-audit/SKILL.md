---
name: project-audit
description: Evidence-backed audit of a named project scope for architecture, security, save-data and content integrity, UX, agent rules or technical debt. Full-repository only when explicitly requested and read-only unless fixes are authorized; not for an ordinary review or a single bug.
---

# Project audit

This skill is for an **evidence-backed audit**; it is not the default entry for every review or bug task. When the user names a topic, audit only that topic and its necessary dependencies; widen to the whole repository only when that is explicitly requested.

When a complex or whole-repository audit needs more dimensions of evidence, read `.agents/skills/project-audit/references/audit-framework.md`. An ordinary scoped audit does not load that reference or the report template by default.

## Standard for a finding

A finding that holds needs at least:

- current evidence that can be traced: a file, function, data contract, migration, test, runtime state and so on;
- a concrete trigger condition and an observable effect;
- a check of existing protections and counter-evidence;
- a root cause and a strength of conclusion that match the evidence (fact / inference / to be verified).

A TODO, complex code, the number of files, a missing test or "a newer version exists" is not a defect by itself. A capability registered as protected, frozen or reserved does not become a finding merely because it is unfinished, has no entry point or is little used; real security, data, build and data-contract problems are still audited normally.

## Scope and coverage

- Start by default from the user's question and the nearest source of truth, and stop when the evidence is enough to answer it. Do not scan unrelated areas such as saving, security, UX or release in passing.
- When the user asks for a full audit of a directory or a topic, cover **that scope** completely; a whole-repository audit additionally builds a repository-level coverage record. When a key area cannot be read, downgrade explicitly to a partial audit.
- A listing, a search or a static scan is only discovery; read the necessary context and counter-evidence before forming a finding.
- Before marking something as high severity, ask: if it were true, should a published build or CI not have broken long ago? When the same code has run for a long time without the matching symptom, downgrade or drop the finding and write down the counter-evidence.
- A declaration that was accepted is not a runtime that implements it: for a data contract, a configuration field or a switch, confirm that there is a real consumer.
- No findings does not mean complete coverage: Unknowns state which ranges were not read, and a summary that was truncated or shortened says what was left out.
- Keep one main finding per root cause and list several symptoms as its affected range. Severity is used only when it helps ordering; problems or scores are not made up for a complete report.

## Audit and repair

Collecting audit evidence stays read-only. When the same request from the user has already explicitly authorized "fix clear problems that are found", a high-confidence finding may be handed over to the normal flow of the matching path rule, `ui-design` or `content-authoring`; local repair permission is not asked for again because the work went through an audit first. Dependencies, Git, release, third-party and other independent actions are still judged by the real boundary of authorization.

The size of a repair is set by the root cause: a local cause gets a local fix. When state ownership, the single source of truth or an architecture boundary is wrong, point out or repair the necessary mechanism; do not keep a structure proven wrong for the sake of the smallest diff, and do not grow the repair into an unrelated refactor either.

## Verification and delivery

The default output needs only: the conclusion, the findings ordered by impact, the key evidence, the real Unknowns, and repair priorities where needed. When there is no high-confidence problem, say so directly and do not manufacture a finding.

When an authorized repair took place, run the smallest sufficient verification for the paths really changed, and confirm again that the trigger mechanism of the original finding is gone; what was not really run is marked not verified. An archived report uses `.agents/templates/project-audit-report.md` only when the user explicitly asks for one.
