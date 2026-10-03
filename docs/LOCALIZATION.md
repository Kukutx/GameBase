# Localization

GameBase separates interface localization from authored dialogue localization.

## Supported UI locales

The current UI locale set is:

- `en` — English
- `zh_CN` — Simplified Chinese

The selected locale is stored in `user://settings.cfg` by `GameSettings` and applied through Godot's `TranslationServer`.

The settings menu exposes the locale selector and persists changes automatically.

## UI strings

Committed UI translations live under:

```text
game/i18n/
```

Current Simplified Chinese catalog:

```text
game/i18n/ui.zh_CN.po
```

Scene-authored Control text participates in Godot translation automatically. Runtime-created text must use `tr(...)` or `TranslationServer.translate(...)` for translatable labels.

Stable gameplay IDs, save keys, resource IDs, location IDs and internal enum/string values must never be translated.

## Dialogue

Dialogue Manager remains the authored-dialogue layer. Dialogue source files under `game/dialogue/` are registered as translation sources in `project.godot`.

Keep dialogue translation data separate from gameplay state. Translation changes must not alter dialogue title IDs used by heart events or NPC progression.

## Adding a locale

1. Add the locale ID and display name to `GameSettingsService`.
2. Add a PO catalog under `game/i18n/`.
3. Register the catalog in `project.godot`.
4. Add/extend automated translation tests.
5. Verify the locale through the settings menu and a real exported build.
6. Verify fonts cover all glyphs required by the locale.
