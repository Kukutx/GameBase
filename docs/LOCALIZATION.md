# Localization

GameBase separates interface localization from authored dialogue localization.

## Supported UI locales

Source text is English (`en`). A game supports English and every locale it registers a translation catalog for in `locale/translations`; `GameSettings.get_supported_locales()` reads them from `TranslationServer`, and the language picker names each one in its own language. Farm1 and a new game support:

- `en` — English
- `zh_CN` — Simplified Chinese

The selected locale is stored in `user://settings.json` by `GameSettings` and applied through Godot's `TranslationServer`. Runtime-created HUD/menu/interact text must pass through `tr(...)`; input prompts also update when the active input device changes.

The settings menu exposes the locale selector and persists changes automatically.

## UI strings

Text is translated in the layer that owns it, so a string the foundation shows is translated once for every game:

```text
gamebase/core/i18n/core.<locale>.po                 the core's text
gamebase/modules/<module>/i18n/<module>.<locale>.po each module's text
games/<id>/game/i18n/ui.<locale>.po                 the game's own text, data and dialogue
```

A game registers, in `locale/translations` of its `project.godot`, the catalogs of the core, of every module it uses and its own; `node tools/link.js` writes that list from the catalogs under `gamebase/core/i18n/`, each listed module's `i18n/` and the game's `game/i18n/`. Farm1 registers the core, all six module catalogs and `games/farm1/game/i18n/ui.zh_CN.po`; Ember Depths the core, `items`, `skills` and `combat` and its own; a game created by `node tools/new_game.js` starts with the core's catalog and its own.

Scene-authored Control text participates in Godot translation automatically. Runtime-created text must use `tr(...)` or `TranslationServer.translate(...)` for translatable labels.

Stable gameplay IDs, save keys, resource IDs, location IDs and internal enum/string values must never be translated.

`tools/check_localization.js` scans runtime translation calls, player-visible scene properties, authored Dialogue Manager lines/responses, and player-facing data resource fields such as `display_name`, `title`, `description`, `subject`, `body`, `role`, `activity` and a calendar's `season_names`. For each locale the game registers, every string of a layer needs a non-empty entry in a catalog of that layer or of a layer below it (the core below a module, the modules a module requires, directly or not, below it, everything below the game). It also fails when the game does not register a catalog that a layer it uses ships for that locale, and when two registered catalogs translate the same string, so each string has one owner.

The check also keeps every entry in the right catalog. An entry has to translate a string its own layer holds anywhere: a script literal, a scene or resource property, or a dialogue line. An entry no text of its layer holds is reported, so a removed string takes its entry with it. A string that a layer below also holds is translated by the lowest such layer: the core's text in the core's catalog, a module's in that module's catalog rather than in the catalog of a module that requires it, and never in a game's. This covers the text the coverage scan below cannot see, such as the weather names, the control labels and the skill names, so every game that uses those layers gets their translation. This check is part of `tools/validate.js` and therefore part of CI and release readiness.

## What the coverage gate can and cannot see

`tools/check_localization.js` reads a game's own `games/<id>/game/`, `gamebase/core/` and the modules the game uses (`gamebase/modules/<module>/`), and finds a string only in these positions:

- in `.gd` scripts: every string literal that sits directly in the first argument of `tr("...")`, `GameEvents.toast("...")`, `GameEvents.toastf("...")` or `set_prompt("...")`, including both branches of a conditional;
- in `.gd` scripts: the default of an exported text property (`@export var display_name := "..."`) or text list (`@export var season_names := PackedStringArray([...])`) and a literal assigned to a text property from code (`interactable.prompt_text = "..."`);
- in `.tscn` scenes: the properties `text`, `display_name`, `station_name`, `idle_text`, `dialog_text`, `prompt_text`, `title`, `ok_button_text`, `cancel_button_text`, `placeholder_text`, `tooltip_text`, `pending_text` and `completed_text`;
- in `.tres` resources, such as a game's data and the controls and calendar of its `game_definition.tres`: `display_name`, `title`, `description`, `subject`, `body`, `role` and `activity`, and each name in `season_names`;
- authored lines and responses in the game's `.dialogue` files.

A player-visible string anywhere else passes the gate without a translation. The usual ways to end up there:

- the string is kept in a constant, a dictionary or a variable and translated later, such as `tr(message)` on a message that arrived through a signal or `tr(SKILL_NAMES[skill])`;
- a service returns finished English text and the caller translates the result;
- the string is passed through a helper before it reaches a translation call, such as a private `_commit(message)` that ends in `GameEvents.toast(message)`.

Write each visible string as its own literal call so the gate covers it. Where a string has to travel as data, add its PO entry by hand in the catalog of the layer whose code or data holds it, and say so in the change. Nothing reports such an entry missing; the placement check above only makes sure that it sits in the right catalog and is removed with its string.

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

Dialogue Manager remains the authored-dialogue layer. Dialogue source files under `games/farm1/game/dialogue/` are registered as translation sources in `games/farm1/project.godot`. The current Mira, Neri and Rowan authored dialogue lines and player responses have Simplified Chinese coverage in Farm1's `games/farm1/game/i18n/ui.zh_CN.po`; character names use the `dialogue` PO context expected by the Dialogue Manager balloon.

Keep dialogue translation data separate from gameplay state. Translation changes must not alter dialogue title IDs used by heart events or NPC progression.

## Adding a locale

1. Add a `<name>.<locale>.po` catalog to the core, to every module the game uses and to the game.
2. Run `node tools/link.js`, which registers them in the game's `locale/translations`; the locale then appears in the language picker. If `GameSettingsService.LOCALE_NAMES` lacks the language's own name, add it there.
3. Add/extend automated translation tests.
4. Verify the locale through the settings menu and a real exported build.
5. Verify fonts cover all glyphs required by the locale.
