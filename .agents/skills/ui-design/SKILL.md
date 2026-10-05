---
name: ui-design
description: Analyze or implement the structure, interaction and visuals of game UI screens, including reproducing a UI reference and UI prototypes. Use for menu, panel and other `Control` scene work; not for text-only changes, non-UI code, or a gameplay root cause that merely shows up on a screen.
---

# UI design

This skill handles UI structure, interaction, visual implementation, and an explicit reference reproduction or experimental prototype. An ordinary text change, non-UI code, and a gameplay or service root cause where "the error just shows on the screen" do not trigger it.

The UI here is made of Godot `Control` scenes under `CanvasLayer` roots, on a 480×270 base viewport stretched with `canvas_items`, operated with keyboard and gamepad focus, in English and Simplified Chinese.

## Decide the mode first

- **Analysis / review**: when the user wants a judgement or advice, stay read-only and create no implementation files or prototypes.
- **Regular implementation**: when a change or a redo is explicitly requested, finish the necessary structure, interaction and visual details inside the authorized screens and controls.
- **Pixel-level reproduction**: enable it only when the user explicitly asks for "exactly the same", "pixel-level" or "the reference image is the acceptance baseline".
- **Experimental prototype**: enable it only when the user explicitly allows mocking a concept or data that does not exist yet. It does not bring authorization for services, the save schema, the content manifest, release configuration or a release.

On entering **pixel-level reproduction**, read the "Pixel-level reproduction" branch of `.agents/skills/ui-design/references/modes.md`; for an experimental prototype or a whole-screen production closing, read that file only when the matching detailed boundary is needed. When an external or local visual reference has to be found, read `.agents/skills/ui-design/reference.md`, and use `.agents/skills/reference-projects/SKILL.md` when a reference project has to be read; when a clear reference already exists, do not load the reference library for inspiration. A reference whose behaviour, timing or numbers must match, beyond how a screen looks, goes to `.agents/skills/replication/SKILL.md`. When the user explicitly asks for a visual upgrade, for removing the template look or for more identity, or when a new screen is designed without a reference image, read `.agents/skills/ui-design/references/visual-quality.md`; a local layout fix, a pixel reproduction and an implementation with a clear reference do not read it.

## Shared design boundaries

- First identify the player's current task, the kind of screen, the information hierarchy, the primary and secondary actions and the real states; then decide what to add, remove, merge or restructure. "Fuller", "cleaner" or "more premium" is not a quality standard.
- Use a reference for the purpose the user named: the layout, elements, text, colours or motion the user explicitly asks to match are the acceptance basis for that dimension and are not downgraded to inspiration for a different version; patterns are extracted only when the user asks only to borrow. Interaction and game behaviour the reference does not show go back to the current game facts and are not guessed from a static image. New capabilities, legal commitments and third-party brand or art assets are still handled by real authorization; when there is a conflict, state the specific difference and do not replace silently.
- In an authorized implementation, spacing, typography, hierarchy and the visual details of existing elements may be settled autonomously; **whether a player-visible element exists** is not an ordinary visual detail. Without a basis in the task or in a real state, do not add a button, panel, toast, badge, explanation, subtitle, empty-state action or motion.
- When the user has authorized a whole-screen redo and the old skeleton blocks the goal, the structure may be replaced inside that screen. A local fix keeps the surrounding structure stable and does not grow into a whole-screen or neighbouring-screen restructuring in the name of consistency.
- Reuse first: the shared theme (`game/ui/game_theme.tres`), the existing scenes and controls, the translation catalogue, real data and the results the owning service already provides. Do not cover a state-ownership or structure root cause with margins, wrapper nodes or duplicated state.
- Lay a screen out with containers and anchors at the base viewport size, so that it holds when the window is stretched and when the text is in either language; every interactive control stays reachable with keyboard and gamepad focus.
- Do not replace protected assets, the palette or key player-facing text. The specific constraints for scenes, text and the theme are read on demand from the current path, domain and text sources of truth: `.agents/rules/scenes-resources.md`, `.agents/rules/localization.md` and `.agents/rules/project-domain.md`.

## When to read game semantics

A pure pixel or style comparison that does not change structure, state or behaviour does not need the game context. When the work changes a navigation entry, the player's task, how a state is expressed, roles or permissions, game behaviour or whether a feature stays, read the Domain rule and the game invariants through the repository's routing, and go by the current data contracts and the capability results of the owning service; do not invent game rules from the UI.

## Verification and completion

Regular UI work verifies only the states and the scaling and interaction boundaries this change directly affects; an ordinary screenshot may be used on demand where layout, occlusion, scaling or visual regression needs it. A pixel task closes with comparable screenshots or key frames and a deterministic gate as in `references/modes.md`; other verification still prefers the game's existing run entry and the smallest relevant check. A headless run does not show what a screen looks like; a visual claim rests on a windowed run or a screenshot, and is otherwise reported as not verified.

When UI QA is carried out, or the task has asked for the UI to be visible during the work, operate the game as described in `.agents/skills/game-qa/SKILL.md`, and save and show the different screens really met inside the authorized scope. The range covered, the evidence of the process and the pass conclusion are judged separately; screenshots are not filtered by whether something was fixed, and the request is not forgotten when a new round starts.

Completion means the screen or control reaches the player's current task and the explicit acceptance goal, the real data, states, permissions, translations and theme are still closed, the UI record the user asked for can be viewed, and the checks really run agree with what is claimed. Stop once the goal is reached; do not fill in every possible state automatically for the sake of a "complete UI".
