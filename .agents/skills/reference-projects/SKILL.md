---
name: reference-projects
description: Compare a reference project or codebase that the user or the current session supplies and map its transferable patterns onto this project. Not for screenshot-only visual references or for exact reproduction; references are not requirements.
---

# Mapping a reference project

This skill is responsible only for: **choosing the most relevant reference → reading it selectively → extracting what can be transferred → mapping it onto the current project**. UI design itself goes to `ui-design`; reproducing a reference with exact verification goes to `replication`; carrying a change through data resources, saves, scenes and tests goes to `content-authoring`.

## Choosing a reference

Reference repositories are kept outside this repository and are not production dependencies. When a reference has to be chosen from the registered pool, read `.agents/skills/reference-projects/reference.md`. When the user has already named a specific project or file, start directly from that entry point; do not load the whole index or several references "to look around".

The reference root must come from a path the user explicitly provided or one confirmed in the current session. Do not scan the whole machine, a personal knowledge base or an unauthorized pool of references to look for inspiration.

## Mapping principles

- A reference project is a sample implementation. It is not a source of truth for this project's requirements, versions, permissions, game rules or compatibility strategy.
- Read only the scenes, scripts, state, services, data resources and tests that can answer the current question; widen when the evidence is not enough or when the user explicitly asks to compare more sources.
- Separate three kinds of content: structure and mechanisms that can be borrowed directly, parts that have to be adapted to this project, and what cannot be transferred — brand and art assets, game rules, and the inertia of an older architecture.
- A reference's dependency versions and compatibility layers only explain why the reference does it that way; the choice here is still decided by this project's engine baseline and vendored addons, its real support obligations and the current officially supported facts.
- When the user asks for long-term follow-up, exact reproduction or continued comparison later, record a reference commit, version or snapshot that can be located again; after the reference changes materially, an old conclusion of agreement or difference is treated as out of date and the comparison is made again. An ordinary one-off borrowing does not get an extra version system for this.
- External source code, images, audio, fonts, icons and paid templates or asset packs do not gain authorization to be copied into the game because they are a "reference"; use in the game follows the licence and the project's asset boundary.

## Completion

The output converges on: `reference point -> entry point in this project -> necessary adaptation -> how to verify`. Without a reference that can be verified, do not claim "pixel-level" or "exactly the same", and do not make up a reference implementation. When the user only wants analysis, stay read-only; when implementation is explicitly requested, hand over to the matching normal implementation flow.
