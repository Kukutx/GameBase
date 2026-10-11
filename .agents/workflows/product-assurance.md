# Product assurance: multi-agent orchestration

Use this only for a quality audit or repair loop that is **product-level, crosses several entry points and states, and really has value in a division of work or in independent re-verification**. An ordinary single bug, a local UI problem on one screen, or an ordinary content change keeps using the matching path rule / `project-audit` / `ui-design` / `content-authoring` / `game-qa`; this workflow is not entered for the sake of a complete process.

This page is responsible for coverage, merging findings, the division of specialities and re-verification. It is not a second set of project rules, a source of authorization to change things, or a reporting system.

## Shared goal

- First define the flow, feature or group of screens this round covers and success criteria that can be verified. When the user only asks for an audit, stay read-only; when repair is already explicitly authorized, local repair is not confirmed again finding by finding.
- Build coverage from the real scenes and navigation, conditional entry points, player and world states, panels, dialogs and overlays, world travel between locations, the capabilities the owning services expose, the data contracts, the tests and the necessary runtime evidence. Without discovery, do not claim that "everything was checked".
- For the same owning module, source of truth, interaction mechanism or root cause in the shared theme, keep one main finding and list the affected range. What is already healthy is marked and kept stable; nothing is changed again just to produce output.
- Escalate to a Product Decision only when whether a feature stays, what is exposed to players, permissions, save data and player progress, a legal commitment, or several reasonable options would change what the player experiences. Deterministic discovery, defect repair and re-verification are closed by the machine inside the existing authorization.

When the game's structure, entry points, states, roles or whether a feature stays are involved, read the Domain rule and the game invariants through the repository's routing. A specialized method is loaded only when its problem appears; not every skill is pre-read.

## Specialist routing

| Problem | Use |
| --- | --- |
| Player value / whether a feature stays | The current game invariants plus the player's goal; the conclusion may use `KEEP / POLISH / SIMPLIFY / MERGE / REDESIGN / REMOVE / NEEDS_EVIDENCE`, but no decision is manufactured for the sake of the classification |
| UI / hidden states / interaction | `ui-design` |
| Mechanism / architecture / evidence-backed finding | `project-audit` |
| Crossing data contracts and consumers | `content-authoring` |
| Runtime evidence from operating the game | `game-qa` |
| Repair | Back to the normal implementation flow of the real owner |
| Re-verification | Verify the finding's acceptance criteria and the necessary regression again; the statement "it is fixed" is not accepted as evidence |

Do not make up agent roles mechanically. A task one agent can do reliably does not take on collaboration cost for the sake of "independence". But when the host supports collaboration, the scope holds several evidence surfaces or entry points that are independent of each other and heavy enough, and parallel work clearly shortens the collection of evidence or gives truly independent re-verification, delegate actively by non-overlapping file or evidence ownership; the main agent unifies the findings, the judgement of conflicts and the final re-verification. Shared writes, a strong dependency chain and a repeated investigation of the same root cause stay in sequence.

## Coverage and findings

When a complex or long-running task has to be recorded across batches, use the minimum coverage states:

- `DISCOVERED_UNREVIEWED`
- `STATIC_REVIEWED`
- `RUNTIME_REVIEWED`
- `VERIFIED_HEALTHY`
- `OPEN_FINDING`
- `BLOCKED`

While the core scope still has an unknown entry point or a key `DISCOVERED_UNREVIEWED / BLOCKED` item, do not declare coverage complete.

A finding keeps only what repair and re-verification need:

- `ID`
- `Type: Defect / Product-UX Debt / Architecture-Mechanism`
- `Impact`, `Confidence`
- `Scope / Player impact`
- `Evidence: Fact / Inference / Unknown`
- `Root cause`
- `Recommendation`
- `Acceptance criteria`
- `Regression scope`
- `Do not do / Unknowns` (only when needed)

Do not fill empty fields or reach a fixed number of findings for the sake of a complete protocol.

## Threshold for a runtime anomaly to become a finding

An anomaly seen during interactive exploration is first recorded as a candidate and is not upgraded to a Defect at once. When it can be reproduced safely, prefer a controlled reset, a replay or a minimal reproduction that runs the same path again. When a one-off crash, an external failure or an environment condition cannot be rebuilt reliably, a finding may also be formed from direct crash, trace, contract or state evidence, but the limit on reproduction is stated. Then classify it as:

- product defect: it reproduces stably under the same premises, or reliable crash, trace, contract or state evidence already points clearly at the current game behaviour or implementation; when it could not be replayed, the limit on reproduction is kept;
- agent / driver mistake: the path taken, the input, the automation script or the test run itself was wrong;
- environment issue: caused by an environment premise — the device, the engine build differing from the baseline, a headless run, missing local-only assets or export templates, permissions, rendering or timing;
- expected behaviour: the current data contract, the game facts or the platform rules explicitly allow or require it;
- unknown: the evidence is insufficient or the result is unstable.

Only a product defect, or a structural problem with sufficient static evidence, becomes a formal finding. A runtime anomaly that cannot be reproduced stably does not have its severity raised because "it looks like a bug". A path that was reproduced stably and fixed is preferably settled as a deterministic regression in the existing test, driver or replay system — a GUT test under `games/<id>/test/unit/` or a check in a runtime script under `games/<id>/test/runtime/` — instead of depending for the long term on an agent repeating the steps by hand.

## Execution and stopping

Advance dynamically around the current evidence, not by a fixed number of batches or steps: discover the real entry points and states → form or refute findings → merge those with the same root cause → repair by root cause when authorized → re-verify with independent evidence. Ask for the smallest necessary input only when a device, an account, an external condition or a design decision truly cannot be obtained by the machine.

On a failure, conflicting evidence, a low-confidence subjective judgement, a growing effect or a missing safe recovery path, mark `BLOCKED`. The parts where evidence can be added or work can be done safely continue; the whole batch is not handed back to a person. A read-only audit may keep clearly recorded open findings once the planned scope is covered. If the current request has already authorized repair, the high-confidence findings **inside the authorized repair scope** must be repaired and re-verified as necessary; a part that cannot be finished must have a real `BLOCKED` reason, and "explicitly left open" alone is not a stopping condition. Stop once the completion condition of the current task mode is met; do not produce a backlog without limit.

## Handover between sessions

Keep this only when a long task really needs a new session or parallel work:

```text
Batch / Scope:
Goal / Authorization / Constraints:
Changed files / Ownership:
Verification evidence / Remaining checks:
Covered / Open findings / Verified healthy:
Blocked / unknown / Not covered yet:
Next recommended batch:
```

Do not copy the whole conversation, private reasoning or a temporary brainstorm. A repository file is written only when the user explicitly asks for an archive.
