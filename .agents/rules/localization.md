---
path: "gamebase/core/i18n/**, gamebase/modules/*/i18n/**, games/*/game/i18n/**"
---

# Localization (`gamebase/core/i18n/**`, `gamebase/modules/*/i18n/**`, `games/*/game/i18n/**` and any player-visible text)

The facts, the supported locales and the coverage gate are described in `docs/LOCALIZATION.md`; read it before adding or changing player-visible text. This rule holds what an agent has to do.

## P0

- Every player-visible string — UI, toast, prompt, authored Dialogue Manager line or response, dialog, placeholder, tooltip, project-progress text and the player-facing data fields `display_name`, `short_name`, `title`, `description`, `subject`, `body`, `role`, `activity` and each of a calendar's `season_names` — has a non-empty Simplified Chinese entry in the catalog of the layer that owns it: `gamebase/core/i18n/core.zh_CN.po` for the core, `gamebase/modules/<module>/i18n/<module>.zh_CN.po` for a module, the game's `games/<id>/game/i18n/ui.zh_CN.po` for the game's own text, data and dialogue. A string is translated once, by its lowest owner (the core below every module, a module below the modules that require it); a game never repeats the foundation's entries. `node tools/check_localization.js` is a release gate.
- Stable gameplay ids, save keys, resource ids, location ids and enum or string values used by code are never translated.
- A translation change does not alter the dialogue title ids that heart events or NPC progression refer to.

## P1

- Write each visible string as its own string literal inside `tr("...")`, `GameEvents.toast("...")`, `GameEvents.toastf("...")` or `set_prompt("...")`. The gate reads only those positions, the listed scene and resource text properties, the exported defaults of those properties, and literals assigned to them from code. A string kept in a constant, a dictionary or a variable and translated later, or returned by a service and translated by the caller, passes the gate without a translation; when a string has to travel as data, add its entry by hand to the catalog of the layer that holds the string and say so in the change. The check reports an entry its layer does not hold and an entry of a game that the core or a module holds.
- Translate the template, then format: `tr("Save Slot %d") % slot`. Text formatted first can never match an entry. A service that produces text for the UI translates its own template, or hands over the template and its arguments the way `GameEvents.toastf(template, args)` and `Interactable.set_prompt(template, args)` do.
- Build a sentence from one template with placeholders, not by joining translated fragments.
- Text assigned from code keeps the language it was assigned in. A node that assigns visible text from code connects `GameSettings.locale_changed` and runs its refresh again.
- Text typed by the player is data: it is not passed to `tr()`, and `[` is replaced with `[lb]` before it goes into a `RichTextLabel` with BBCode enabled.
- A new control's `display_name` is translated in the catalog of the layer that declares the control: the core's controls in the core's catalog, a game's in the game's.

## Verification

- `node tools/check_localization.js` after any change to visible text; `--report-only` prints the gaps without failing.
- `games/farm1/test/unit/test_localized_runtime_text.gd` runs the text that services format for the HUD and the menus in Simplified Chinese and fails on an untranslated word; a new summary, status or result text gets a case there.
- A string that only appears after an action (a status line, a toast) is also checked in the running game with the locale set to Simplified Chinese, because the gate cannot prove that it is shown translated.
