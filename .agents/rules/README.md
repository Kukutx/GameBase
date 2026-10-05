# Agent rules: maintainer note

This directory holds the boundaries an agent works within and the overlays for this repository. It does not hold long descriptions of game facts. The loading entry, path routing, conditional context and conflict priority are maintained only in the root `AGENTS.md`; this page explains the layers to maintainers, and an agent does not need to read it.

## Layers

| File | Responsibility | When it is loaded |
| --- | --- | --- |
| `AGENTS.md` | Safe defaults, path routing, conditional context map | Every task |
| `project.md` | Generic boundaries for authorization, high-risk actions, data contracts, evolution, implementation and verification | When that judgement is needed |
| `project-profile.md` | Repository identity, engine and addon policy, language, fact roots, tool and process entry points | When repository-level facts are needed |
| `project-domain.md` | Game domain invariants: content ids, save compatibility, audio cues, world travel, dialogue, licensed art | When a game-design or domain judgement is needed |
| `ci-performance.md` | Efficiency constraints for CI, the build and release chain, the test strategy and automated gates | For the matching path or task |
| Other `*.md` | Path and technology overlays that keep the concrete facts and command entry points which really change execution | Only for a task on the matching path |

The `path` in a path rule's frontmatter must agree with the path routing table in `AGENTS.md`; the rules validator checks this.

## Maintenance

- A rule has one owner. Other files reference the owner and do not copy long passages. The "load on demand, do not pre-read" explanation that `AGENTS.md` already carries is not repeated in each file.
- When the model or the host changes, use `.agents/workflows/instruction-readiness.md`; when a skill is added or changed, use `.agents/standards/skill-authoring.md`. No model-specific global rules are added.
- Delete first: unconditional pre-reading, repeated authorization sentences, fixed numbers of steps or test runs, and scaffolding that only compensates for an older model. Keep: real domain knowledge, permission boundaries, failure guards, executable recipes and completion conditions.
- After `.agents` changes, run `node tools/validate_rules.js --strict` (`--report` prints the source-byte footprint only; it is not a token count and not the amount actually loaded), and review rule consistency against the relevant scenarios in `.agents/workflows/agent-pressure-tests.md`. Static validation and a real model replay are reported separately.
