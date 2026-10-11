# Agent development workflow

Use this page only for work that **crosses data contracts or systems, touches a published build or a release, changes save data, is a complex audit, has an unclear owner or source of truth, or is an important architecture trade-off**. Do not load it for an ordinary single-path task, or for a task that already hits a fixed CI or review recipe directly.

The binding boundaries are still set by the current user scope, the applicable sections of `.agents/rules/project.md`, the Profile and the real path and domain overlays. This page only routes and closes complex tasks; it does not copy a second set of rules.

## Fix the completion condition of a complex task first

Read directly from the current request: the goal, the allowed scope, the explicit exclusions, the real deliverable, how completion is verified, and which actions are already explicitly authorized. Facts that can be confirmed from the repository or from safe read-only state are checked first. Ask only when the remaining ambiguity would change game, save-data, player-progress or permission semantics, a high-risk action or an irreversible result.

The completion condition covers the whole user goal, for example "implement → run the related path → check the result → fix the problems this change caused". Do not set a mid-way stop such as "wait for confirmation after the first version" that has no real decision value.

## Choosing context

Rule and fact entry points are chosen by the conditional context in the root `AGENTS.md`, and specialized methods by "Specialized routing" below; the whole set of material is not pre-read in a fixed order. A search hit, a directory listing or truncated output only locates something. When the user asks for a full audit of a named scope, complete coverage evidence for that scope still has to be built.

## Player-visible changes

Check these questions only when the task adds, removes or materially changes a player-visible structure, entry point, state, permission, flow, or whether a feature exists:

- What is the player really trying to do, and which system or domain does the change belong to?
- Does the owning service already provide the conclusion (whether an action is available, the current state, what to display)? If so, the UI does not derive it again.
- Are "visible", "available", "unlocked", "in progress" and "completed" wrongly pressed into one state?
- Are different facts being mixed: locale, a stable id, a display name, a location, in-game time and real time?
- Does "the code exists" really mean the feature is open in a release? Where needed, check the content registration in the game's content manifest (`games/farm1/game/data/content_manifest.tres` for Farm1), the scene that reaches it, the settings, and what the export includes.
- After something ends or is cancelled (a quest, an event, a day, a conversation), which abilities are still legitimate? Do not close every later behaviour at once with a single terminal flag.

Skip this group of checks for a pure pixel or style fix that does not change structure, state or behaviour.

## Principles for carrying out a complex task

- **Source of truth first**: start from the target code and its direct call chain, then the data contracts, schema, configuration and manifest, then fact documents, then tools and CI. Old plans and old reports only give leads.
- **The root cause sets the size**: a local defect gets a local fix. When a shared owner, state ownership, the single source of truth or a contract mechanism is wrong, fix the mechanism directly and do not stack a workaround.
- **Synchronize only the real effect**: crossing systems does not mean sweeping the whole project. Synchronize only the data contracts, generated output, consumers, translation entries, tests and fact documents the current change needs.
- **Evolution on demand**: read and apply the evolution strategy only when compatibility, migration, a version or a schema change would change the solution, and let real consumers, real data and external contracts override the default label.
- **Tools and parallelism by real capability**: independent reads and checks may run in parallel; steps with a dependency or a shared write run in sequence. When the host really supports collaboration and there are two or more sub-problems that are independent of each other, heavy enough, and where parallel work clearly saves time or gives independent re-verification, delegate by non-overlapping file or evidence ownership and let the main agent own the boundaries, the conflicts and the final integration. A simple task, shared writes or a strong dependency chain are not split for the sake of "multiple agents".
  - A delegation brief states the behaviour to reach, a completion standard that can be verified independently, and what is out of scope. It refers to existing material by path instead of retelling it. Facts already verified are given with the brief so that the recipient does not look them up again; what is only a guess is marked as a guess, because the recipient treats what is written as settled. The brief also says that the recipient is already the delegated party, finishes the task directly and does not delegate further. Require every conclusion to carry a source that can be checked (file and line, or a link).
  - When independent re-verification is needed, the verifier receives only the object under review and the standard of judgement, without the author's statement of intent or the conclusions of other reviews.
  - For a batch of delegations, reconcile the returned results against the list: what is missing, duplicated or outside the list is all cleared up. A part that was interrupted is redone as a whole; half a result is not used to make up the number.
  - Findings from several reviewers are deduplicated first, then each is verified against the code before it is adopted. When there are no findings, say so explicitly.
- **Verification grows with the risk**: first run the smallest check that proves the current success criteria. Widen only when a failure, a new change or a specific open question leaves the evidence insufficient; do not mechanically repeat an equivalent export or test.
- **A local blocker does not block everything**: finish the other independent, safe, authorized parts first, then report the real blocker.
- **Stop after success**: stop once the whole goal and the necessary regression are met. Suggestions outside the scope are not implemented automatically.

## Specialized routing

| Task | Read on demand |
| --- | --- |
| The user explicitly asks to challenge or grill a proposal, or to align on it in depth; whether to align only or to go on and implement is decided by the authorization the current request already has | `.agents/skills/solution-grill/SKILL.md` |
| UI analysis, screen iteration, reference reproduction of a screen, experimental prototype | `.agents/skills/ui-design/SKILL.md` |
| Comparing with, or migrating from, a reference project supplied by the user or the session | `.agents/skills/reference-projects/SKILL.md` |
| Reproducing a reference with exact verification | `.agents/skills/replication/SKILL.md` |
| A change that must synchronize two or more of: data resources and the content manifest, save data, scenes, translation entries, tests | `.agents/skills/content-authoring/SKILL.md` |
| Runtime state, logs, operating the game, or a difference between a local run and an exported build | `.agents/skills/game-qa/SKILL.md` |
| A scoped or whole-repository evidence-backed audit, or "audit, then fix the clear problems directly" | `.agents/skills/project-audit/SKILL.md` |
| A product-level quality loop that crosses several entry points and states and really has multi-agent or independent re-verification value | `.agents/workflows/product-assurance.md` |
| Changing or reviewing the save schema, save migration, or the meaning of saved player progress | `.agents/rules/save.md`, then the sources of truth it names |
| Licences, notices, licensed art, redistribution, what diagnostics record, platform or store policy, compliance wording | `.agents/prompts/agent-compliance-policy-assistant.md` |
| Engine baseline, addon or tooling upgrades | `.agents/skills/toolchain/SKILL.md` |
| The fixed release, CI and review, or engine upgrade flows of this repository | `.agents/prompts/agent-prompt-shortcuts.md` → the recipe that matches |
| A model upgrade, or an audit of how the agent instruction loading chain, skills and workflows fit | `.agents/workflows/instruction-readiness.md` |
| An important long-term technical trade-off needs recording | `.agents/templates/decision-record-template.md`; no document is created without authorization to persist one |
| A high-risk cross-domain closing really needs a structured check | `.agents/templates/atomic-change-checklist.md` |
| Adding or changing a skill | `.agents/standards/skill-authoring.md` |

Neighbouring skills are combined only when their capability really adds value. For example, an ordinary content change does not load `game-qa` just because it mentions a running game, and an ordinary UI bug is not upgraded to a whole-repository audit because it needs one field from a service.

## Delivering a complex task

The final report covers only the results the user needs to review: what was done, the key grounds, the verification really run, what was not verified, and the real blockers that need a new decision or authorization. When a long task runs over several batches, keep the goal, the authorization, the changed files, the verification evidence and the remaining scope; do not copy the whole conversation or redo an investigation that is still valid.

When `.agents` itself changes, run the current rules validator (`node tools/validate_rules.js --strict`) and review rule consistency against the pressure-test scenarios in `.agents/workflows/agent-pressure-tests.md` that relate directly to this change of behaviour. A static pass does not mean that model behaviour was measured to improve.
