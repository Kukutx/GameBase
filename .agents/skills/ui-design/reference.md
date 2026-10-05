# UI design reference entry

This file holds only reference sources and how to use them; it states no facts about this project. A reference serves to study patterns and does not have to be adopted; the real task follows the modes of `.agents/skills/ui-design/SKILL.md`, the current project rules and what the user authorized.

## Rules of use

- Look at the flow of a real game first, then at visual inspiration.
- Abstract the pattern first, then adapt it to this project.
- Do not copy a brand, art, text, a paid template or complete component code.
- The states covered match the scope of the task: a local fix looks only at the directly related states; only a whole-screen restructuring or an explicit production closing checks loading, empty, error, locked, disabled, long text, both languages, scaling and focus states systematically.
- A feature, entry point or state in a reference that this game does not have is only noted as a difference in an ordinary task; only when the user explicitly authorizes an experimental prototype or a reproduction of those concepts are they expressed with a local mock or a presentation-layer state.
- A local reference root must come from a path the user explicitly provided or one confirmed in the current session; no absolute path of a machine is written into a skill or a reference.

## Local reference code

When a reference project has to be read for a screen, use `.agents/skills/reference-projects/SKILL.md`, and first confirm from its README whether it is a read-only reference, experimental code or production code. Do not assume that a fixed directory exists on every machine.

Look at:

- how the screen is divided into areas, layers, scroll areas and fixed action areas;
- how menus, panels, tabs, lists and detail areas are organized;
- spacing, proportions, font sizes, visual density and interaction states;
- which reference concepts relate directly to the current goal and which are only inspiration or experimental candidates.

## Engine UI documentation

- Godot user interface tutorials: https://docs.godotengine.org/en/stable/tutorials/ui/index.html
- Keyboard and controller navigation and focus: https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html
- Multiple resolutions and stretch modes: https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
- Input: https://docs.godotengine.org/en/stable/tutorials/inputs/index.html
- Internationalization: https://docs.godotengine.org/en/stable/tutorials/i18n/index.html

The class reference of the engine version in `.godot-version` decides what a `Control` node really does.

## Game interface references

- Interface In Game: https://interfaceingame.com/

Look at the title screen, the pause menu, inventory and storage, shops, dialogue, the quest log, the map, settings and key rebinding, save slots, and empty and error states.

## Pixel art and palette

- Lospec palette list: https://lospec.com/palette-list

The palette and the art direction of this game are protected; a palette reference is for analysis and is not a reason to change colours.

## Motion

- Easings: https://easings.net/

## Accessibility and usability

- Game Accessibility Guidelines: https://gameaccessibilityguidelines.com/
- Xbox Accessibility Guidelines: https://learn.microsoft.com/en-us/gaming/accessibility/guidelines
- WCAG: https://www.w3.org/WAI/standards-guidelines/wcag/
- Nielsen Norman Group: https://www.nngroup.com/articles/

## Judging for this project

Confirm at least three things:

1. Does the reference solve the same problem as the current goal?
2. Which structures and interactions can be transferred, and which are only a brand, a showcase or a game concept that does not exist here?
3. After the transfer, does the screen still hold at the base viewport size, in both languages, with keyboard and gamepad focus, and within the game's states?

Expand a full comparison of theme, scaling, performance and states only when a whole-screen or complex design task really needs it.
