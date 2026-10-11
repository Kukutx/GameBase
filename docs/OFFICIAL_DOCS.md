# Official Documentation Index

**Purpose**: looking up syntax, breaking changes, the shape of an API and platform support. **The versions in use are the ones in the project files** (`.godot-version`, each `games/<id>/project.godot`, the `plugin.cfg` of each vendored addon, `tools/web_smoke/package.json` and its lockfile). The repository's code shows the current implementation; official material shows what that version supports and where its limits are. When the two disagree, find the difference in version or implementation; the current implementation is not assumed to be right.

## Engine

| Topic | Entry |
|------|------|
| Godot documentation (stable) | https://docs.godotengine.org/en/stable/ |
| Class reference | https://docs.godotengine.org/en/stable/classes/index.html |
| GDScript | https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html |
| User interface | https://docs.godotengine.org/en/stable/tutorials/ui/index.html |
| Input | https://docs.godotengine.org/en/stable/tutorials/inputs/index.html |
| Internationalization | https://docs.godotengine.org/en/stable/tutorials/i18n/index.html |
| Exporting | https://docs.godotengine.org/en/stable/tutorials/export/index.html |
| Upgrading between engine versions | https://docs.godotengine.org/en/stable/tutorials/migrating/index.html |
| Engine releases | https://github.com/godotengine/godot/releases |
| Engine download archive | https://godotengine.org/download/archive/ |

The stable documentation follows the newest stable engine. When the baseline in `.godot-version` is older, switch the documentation to the matching version before relying on a page.

## Addons

| Topic | Entry |
|------|------|
| Dialogue Manager | https://github.com/nathanhoad/godot_dialogue_manager |
| GUT (source and releases) | https://github.com/bitwes/Gut |
| GUT documentation | https://gut.readthedocs.io/en/latest/ |

## Tooling and platforms

| Topic | Entry |
|------|------|
| Node.js API | https://nodejs.org/docs/latest/api/ |
| Playwright | https://playwright.dev/docs/intro |
| GitHub Actions | https://docs.github.com/en/actions |
| Git | https://git-scm.com/doc |
| Semantic Versioning | https://semver.org/ |
| Conventional Commits | https://www.conventionalcommits.org/en/v1.0.0/ |
| `SOURCE_DATE_EPOCH` | https://reproducible-builds.org/docs/source-date-epoch/ |

## Distribution

| Topic | Entry |
|------|------|
| itch.io creator guidelines | https://itch.io/docs/creators/quality-guidelines |
| Steamworks documentation | https://partner.steamgames.com/doc/home |

The project publishes GitHub Releases only. These pages are for judging a store question when one is asked; they do not mean a store listing exists.

## Agent hosts and the Agent Skills specification

| Topic | Entry |
|------|------|
| Repository instruction loading (`AGENTS.md` / `CLAUDE.md`) in Claude Code | [Memory](https://code.claude.com/docs/en/memory) |
| Skill discovery paths, frontmatter and the listing budget in Claude Code | [Skills](https://code.claude.com/docs/en/skills) |
| Repository instruction loading and overrides in Codex | [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md) |
| Writing, discovering and progressively disclosing skills in Codex | [Build skills](https://learn.chatgpt.com/docs/build-skills) |
| Current model and prompting guidance | [Model guidance](https://developers.openai.com/api/docs/guides/latest-model) |
| The cross-host skill directory and frontmatter specification | [Agent Skills specification](https://agentskills.io/specification) |

These pages serve to check a host's capabilities and configuration semantics; the project's execution rules are maintained in `.agents/`. Models, context and tool availability follow the current host and its official support.
