# Atomic change checklist

Use this only for a complex change that is high-risk, crosses systems, changes a data contract or save data, changes permissions, touches a release, or needs an audited closing. Do not apply the template to a simple task; the template itself does not widen the user's authorization.

## 1. Goal and scope

- Current goal:
- Explicitly included:
- Explicitly excluded:
- Verifiable success criteria (covering the whole goal):

## 2. Source of truth and impact

- Current source of truth:
- Directly affected paths:
- Consumers / data contracts / fact documents / generated output that must be synchronized:
- Is there a scope the user did not authorize but the task needs to be finished: yes / no
  - If yes, the smallest extension of scope:
- If this decision involves compatibility, migration or a choice of version: what are the current real consumers / data / external contracts / officially supported constraints:

## 3. High-risk judgement

Check only the items the current task really involves:

- Does it change game rules, the meaning of a state, a player entry point or a game flow:
- Does it change permissions, player profiles, deletion of saves or the boundary of sensitive data:
- Does it change the save schema, the meaning of saved data or player progress, or a stable id:
- Does it involve a release, tags, export presets, third-party configuration, secrets, uploads or paid resources:
- Does it add, upgrade or downgrade a dependency (addon, engine baseline, tooling package) or bring in a licence risk:
- Is there a side effect that is irreversible or hard to recover from:

Any "yes" goes back to the current source of truth and to the authorization and evolution boundaries of `.agents/rules/project.md`.

## 4. Implementation

- Root cause / owner:
- Can the existing chain be fixed directly:
- Is a new abstraction / entry point / configuration added:
  - If so, what is the current benefit:
- Is a second source of truth / unfounded compatibility / workaround introduced: should be no
- Is there a change in passing outside the scope: should be no
- Are the orphans / temporary structures this change produced cleaned up:

## 5. Verification and stopping

- Success criteria verified:
- Smallest relevant commands / tests:
- Direct consumers / regression:
- Not verified:
- Blockers / actions that need separate authorization:

Stop once the success criteria and the necessary regression are met; later suggestions are not implemented automatically.
