# Localization

GameBase separates interface localization from authored dialogue localization.

## Supported UI locales

The current UI locale set is:

- `en` — English
- `zh_CN` — Simplified Chinese

The selected locale is stored in `user://settings.cfg` by `GameSettings` and applied through Godot's `TranslationServer`. Runtime-created HUD/menu/interact text must pass through `tr(...)`; input prompts also update when the active input device changes.

The settings menu exposes the locale selector and persists changes automatically.

## UI strings

Committed UI translations live under:

```text
games/<id>/game/i18n/
```

Current Simplified Chinese catalog:

```text
games/farm1/game/i18n/ui.zh_CN.po
```

Scene-authored Control text participates in Godot translation automatically. Runtime-created text must use `tr(...)` or `TranslationServer.translate(...)` for translatable labels.

Stable gameplay IDs, save keys, resource IDs, location IDs and internal enum/string values must never be translated.

`tools/check_localization.js` scans runtime translation calls, player-visible scene properties, authored Dialogue Manager lines/responses, and player-facing data resource fields such as `display_name`, `title`, `description`, `subject`, `body`, `role`, and `activity`. It fails when an entry is missing or empty in any catalog the game registers in `games/<id>/project.godot`. This check is part of `tools/validate.js` and therefore part of CI and release readiness.

## What the coverage gate can and cannot see

`tools/check_localization.js` reads a game's own `games/<id>/game/`, `gamebase/core/` and the modules the game uses (`gamebase/modules/<module>/`), and finds a string only in these positions:

- in `.gd` scripts: every string literal that sits directly in the first argument of `tr("...")`, `GameEvents.toast("...")`, `GameEvents.toastf("...")` or `set_prompt("...")`, including both branches of a conditional;
- in `.gd` scripts: the default of an exported text property (`@export var display_name := "..."`) and a literal assigned to one from code (`interactable.prompt_text = "..."`);
- in `.tscn` scenes: the properties `text`, `display_name`, `station_name`, `idle_text`, `dialog_text`, `prompt_text`, `title`, `ok_button_text`, `cancel_button_text`, `placeholder_text`, `tooltip_text`, `pending_text` and `completed_text`;
- in `games/<id>/game/data/**/*.tres`: `display_name`, `title`, `description`, `subject`, `body`, `role` and `activity`;
- authored lines and responses in the game's `.dialogue` files.

A player-visible string anywhere else passes the gate without a translation. The usual ways to end up there:

- the string is kept in a constant, a dictionary or a variable and translated later, such as `tr(message)` on a message that arrived through a signal or `tr(CONTROL_LABELS[...])`;
- a service returns finished English text and the caller translates the result;
- the string is passed through a helper before it reaches a translation call, such as a private `_commit(message)` that ends in `GameEvents.toast(message)`.

Write each visible string as its own literal call so the gate covers it. Where a string has to travel as data, add its PO entry by hand and say so in the change, because nothing will report it missing.

The gate proves that an entry exists, not that the text is shown translated. `games/farm1/test/unit/test_localized_runtime_text.gd` covers that half: it switches to Simplified Chinese, asks the services for the text they format for the HUD and the menus, and fails on an untranslated word.

## Translate the template, then format

`tr()` looks up the exact source text. Text that was formatted first can never match an entry: `"Slot %d" % slot` followed by `tr()` looks up `Slot 2`.

- Format after translating: `tr("Save Slot %d") % slot`.
- A service that produces text for the UI translates its own template (`tr("Game saved · Slot %d") % slot`), or hands over the template and its arguments, instead of returning a finished English sentence. `GameEvents.toastf(template, args)` and `Interactable.set_prompt(template, args)` translate the template and every `String` argument, then format. The summaries, save and load results and status lines that services return are already in the current language; a caller shows them as they are.
- Text typed by the player is data and is not passed to `tr()`; that includes handing it to `toastf` as an argument.
- Build a sentence from one template with placeholders rather than joining translated fragments, so the word order can differ between languages.

## Text set from code and switching the locale

Text assigned from code keeps the language it was assigned in: a label given `tr("Hello")` still shows the English text after the locale changes, while text typed into a scene property is re-translated by the engine. Confirmed on Godot 4.7.2.

Any node that assigns visible text from code connects `GameSettings.locale_changed` and runs its refresh again, as `world_hud.gd`, `farm_plot.gd`, `interaction_controller.gd` and the menus do. A new label, prompt or list filled from code needs the same connection, otherwise it is correct at startup and wrong after the player changes the language in Settings.

## Dialogue

Dialogue Manager remains the authored-dialogue layer. Dialogue source files under `games/farm1/game/dialogue/` are registered as translation sources in `games/farm1/project.godot`. The current Mira, Neri and Rowan authored dialogue lines and player responses have Simplified Chinese coverage in `games/farm1/game/i18n/ui.zh_CN.po`; character names use the `dialogue` PO context expected by the Dialogue Manager balloon.

Keep dialogue translation data separate from gameplay state. Translation changes must not alter dialogue title IDs used by heart events or NPC progression.

## Adding a locale

1. Add the locale ID and display name to `GameSettingsService`.
2. Add a PO catalog under `games/<id>/game/i18n/`.
3. Register the catalog in `games/<id>/project.godot`.
4. Add/extend automated translation tests.
5. Verify the locale through the settings menu and a real exported build.
6. Verify fonts cover all glyphs required by the locale.
