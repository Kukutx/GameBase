# Automation and Escalation Policy

This page records, for this project, which areas of work a machine completes by default, the conditions for doing so, and the executable entry points. The generic levels (`AUTO`, `APPROVAL`, `DECISION`, `HUMAN_ONLY`) and the authorization boundaries are defined in `.agents/rules/project.md`, "Automation first, and escalation to a person". This page does not replace the code, the workflows, the tools or the live state of a third party. A capability counts as implemented only when the repository or the target platform has an entry point that can be verified.

## Areas

| Area | Default level | The machine completes by default | Escalate to a person when |
| --- | --- | --- | --- |
| Code quality and data contracts | `AUTO` | Import, unit tests, runtime smoke, content and reference validation, localization coverage, the agent rules check (`node tools/validate.js`) | Rules conflict, a breaking change to a data contract, or the real consumers cannot be determined |
| Game quality assurance | `AUTO` | Discovering entry points and states, comparing with the sources of truth, deterministic checks, merging findings, authorized defect repair and independent re-verification | Whether a feature stays, what is exposed to players, save or player-progress semantics, or several reasonable options that change what the player experiences |
| Player reports and diagnostics | `AUTO` | Collecting, deduplicating, classifying, relating a report to a version, a module and known problems, ordering by risk | A commitment to a player, a request for raw save data, or conflicting evidence |
| Save schema and migration | `AUTO` checks, `DECISION` semantics | Migration tests, the save and load soak, the new-game reset check | What an existing save means changes, player progress would be lost, or a migration cannot be reversed |
| Application version | `DECISION` semantics, `AUTO` execution | After a person settles the version, `node tools/update_game_version.js` changes `.game-version` and `project.godot` together | The level of the version change is not settled, or a compatibility boundary changes |
| Engine baseline and addons | `AUTO` observation, `APPROVAL` change | The weekly compatibility run against the newest stable engine, the weekly addon freshness report | Moving the baseline, upgrading or replacing an addon, a major migration |
| Release candidate | `AUTO` | `node tools/release_readiness.js`: the full validation, the three exports with pack verification, the smoke runs, the deterministic archives, the manifest | A release gate is not met, or the settled version or release strategy would have to change |
| Publishing a release | `APPROVAL` | After the tag is pushed, the Release workflow validates, builds, smokes, packages and publishes, and the result is read back | The effect grows, a health signal conflicts, a package would be replaced, or a published release would have to be withdrawn |
| Licences and notices | `AUTO` checks, `DECISION` semantics | The legal bundle matches the engine baseline, the notices are beside every exported build, the licensed source art is absent from every pack | A licence grant, an attribution or what is redistributed would change |
| Security and dependencies | `AUTO` | What an export contains (`node tools/verify_export_contents.js`), addon and engine freshness | A real incident, a public notice, or revoking access |
| CI cost | `AUTO` observation, `APPROVAL` change | Run times, repeated work and trigger analysis | A new paid resource, a self-hosted runner, or a change to which checks are required |

## Conditions for automation

Before work enters `AUTO` or runs unattended, it has the necessary ones of these, according to its risk:

- The authoritative input, the target and the range of objects are explicit.
- Idempotence, deduplication or a retry that can be shown to be safe.
- Boundaries for timeouts, interruption, partial failure and concurrency.
- A structured result, an audit trail and masking of sensitive information.
- A success condition, anomaly thresholds and a stop condition that a machine can judge.
- For a high-impact operation: a preview or dry run, staged execution, and rollback or compensation matching the risk.
- When the automation cannot prove success it returns failed or not verified; "submitted" does not stand in for "done".

When these are missing, first complete the safe collection of evidence and the preparation automatically, then escalate the smallest risky decision. A gap that a tool, a test, a probe or a workflow should fill is not covered by a long-lived manual checklist.

## Game decisions

Game work does not by default require a person to review every screen, state and finding. What can be judged from the scenes, the data contracts, what the owning service reports, the tests, the runtime evidence and the confirmed domain invariants is closed by the machine, and what is healthy is recorded.

The following enter `DECISION` while the current game facts and the existing explicit authorization have not settled their meaning; a specific decision already made is not approved again:

- Adding, removing, exposing, freezing or merging a game capability.
- Changing a player-visible flow, a progression rule, or what a save or a player's progress means.
- Changing prices, yields, rewards or another part of the game economy.
- Changing a licence commitment, a platform policy, what diagnostics record, or the meaning of an irreversible deletion.
- The current sources of truth are not enough to settle the right behaviour among several reasonable options.

Once a decision is clear, the data contracts, the implementation, the consumers, the translations, the tests, the documentation and the re-verification are synchronized by the machine under the current authorization; one decision is not split into item-by-item approvals per system.

## Escalation protocol

Automation escalates to a person only when:

- New evidence goes beyond the authorized objects, target, actions, limits or effect.
- Sources of fact conflict, evidence is insufficient or the result has low confidence, and continuing would change an important meaning.
- An undefined state, a partial failure, no safe retry, or a final result that cannot be verified.
- A risk to save data, player progress, a licence, privacy, irreversible data or significant cost is triggered.
- An automatic recovery would widen the effect, or there is no verified path of rollback or compensation.
- A `HUMAN_ONLY` real-world step has to be completed.

The escalation carries only the facts needed to continue, the effect, what was already completed automatically, and the smallest decision. A local anomaly does not block other independent, safe and authorized automated work.
