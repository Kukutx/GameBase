# Technical decision record template

For an important technical trade-off that affects long-term maintenance, a boundary between modules, or collaboration. A simple implementation detail does not need a decision record. A trade-off worth recording meets three conditions at once: it will be costly to change later; someone without the context would find it strange; and a real choice was made between several workable options. If any one is missing, do not write it. A rejected option is recorded only when its reason holds for the long term and is not obvious.

Using this template is not authorization to persist anything. Write to disk only when the user explicitly asks for a record, or when the currently authorized task explicitly needs a confirmed long-term fact written into the project documentation.

## Decision

- Problem:
- Constraints:
- Choice:
- Reason:

If this trade-off involves compatibility, migration or a version strategy, record under "Constraints" the consumers, data, external contracts and official support requirements that really exist; do not force a lifecycle label onto it for the sake of a complete template.

## Alternatives and trade-offs

Record only the alternatives that would materially change the result; do not make up options for completeness.

| Option | Advantages | Risk / cost | Why not chosen |
| --- | --- | --- | --- |
| A | | | |
| B | | | |

## Impact

- Affected paths / modules:
- Data contracts / generated output / consumers / tests / fact documents to synchronize:
- Does it involve dependencies, game rules, permissions, save data, player progress or a release:
- Actions that need separate authorization:

## Verification

- Success criteria:
- Smallest check:
- Not verified:

## References

- Current project source of truth:
- Necessary official documentation / support matrix:
- Related issue / PR (if any):

## Boundary for persisting

- A conclusion that is currently in force and needs long-term maintenance is written into the formal page closest to the topic, in the fact root that `.agents/rules/project-profile.md` names; no new layer of documentation is added for the sake of the template.
- Migration records, old plans, finished process and the history of the discussion do not enter a page of current facts. They go to a dedicated entry only when the project explicitly has a matching changelog, migration or archive responsibility and there is a real need to keep them.
- Without an explicit request to record, no ADR/DR file, TODO or archive is added.
