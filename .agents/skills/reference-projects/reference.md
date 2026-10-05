# Reference project entry

This file holds **the index of the reference projects currently available and how to choose among them**. It does not hold an absolute path on any machine. The reference root must come from a path the user explicitly provided or one confirmed in the current session.

When a project below does not exist under the authorized reference root, skip it; do not guess a path, download a substitute or scan unrelated disks.

## Rules of use

- Choose a mature project first, then a demo.
- Prefer the same engine generation: a Godot 4 project maps directly, a Godot 3 project gives structure and ideas only and none of its API calls.
- Start from the most relevant reference and add more only for a gap in the evidence or for the comparison the user named.
- Read only the entry points the task relates to; do not expand a whole project.
- A demo is not a source of long-term architecture, but it can be a source for a visual reproduction or a quick prototype.
- The project names in the index only serve discovery in the current reference pool; they are not dependencies of this base and they do not decide its engine or addon versions.

## Task matrix

| Task | Reference names to look for first | Main reference points |
| --- | --- | --- |
| Top-down scene structure, entities and components, interaction, transitions between scenes | `topdown` (`godot-2d-topdown-template`), `make-pro-2d-games` | scene and component layout, the state machine, interaction areas, the inventory, the save file manager |
| RPG overworld, field events, party and combat flow | `open-rpg` (`godot-open-rpg`) | the split between overworld and combat, event sequencing, how data resources drive behaviour |
| NPC behaviour, memory and AI-driven dialogue | `microverse` | the NPC context and memory model, the conversation loop, the boundary between a model provider and game state |
| Authored branching dialogue, cues, the dialogue balloon, translation of dialogue | `dialogue-manager` (`godot_dialogue_manager`) | the addon's own documentation and examples for the version vendored under `addons/dialogue_manager/` |
| Test structure, lifecycle hooks, input in tests, command-line options | `gut` (`Gut`) | the addon's own documentation for the version vendored under `addons/gut/` |

`make-pro-2d-games` was written for Godot 3; read it for structure only.

## Judging a migration

- An implementation task looks first at a mature project on the same engine generation and with the same kind of state ownership.
- A game-flow task may look at a different architecture, but only the flow and the information structure are transferred, not the inertia of the implementation.
- A visual task looks first at a finished game or a complete template and reproduces structure, density, motion and states; it does not transfer a demo's architecture.
- An architecture task looks first at a project whose scene and service boundaries, state ownership and test boundaries are clear.
- The versions, compatibility layers, build commands and platform constraints of any reference are mapped again onto this project; an old reference does not replace the current officially supported facts.

## Reading selectively

After finding the reference project, open only the entry points that can answer the current question, for example:

- the scene and its root script;
- the directly used components;
- the matching state, service or autoload;
- the necessary data resources;
- the tests that relate directly to the question;
- `project.godot` and the addon versions only when a version or dependency judgement depends on them.

Do not read every directory recursively "to understand the whole project".

## Mapping the output

A reference conclusion always converges on:

`reference point -> entry point in this project -> necessary adaptation -> how to verify`

"Necessary adaptation" states what cannot be copied directly because of this project's game rules, state ownership, save schema, translation catalogue, theme, dependencies, export targets or current support obligations.
