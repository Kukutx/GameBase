# Bringing an old Unity 2D project into Tiamat

Tiamat is also where old projects come back to life. `tools/import_unity.js` reads a Unity 2D project as it lies on disk (its scenes, prefabs, `.meta` files, sprites, tilemaps, animator controllers and ScriptableObjects, in the YAML the Unity editor writes) and turns it into Godot resources inside one game of this repository. Unity's C# is never translated: the game rewrites its logic in GDScript on the Tiamat core and its modules, and the import puts that logic on the converted scenes through the game's `scripts` mapping. `games/mfarm/` is the first game made this way; its `game.json` is a complete example.

## Run it

```text
node tools/import_unity.js --game <id> [--source <unity project>] [--dry-run]
```

The source is `unity_import.source` of the game's `game.json` (relative to the game directory) unless `--source` names one. Everything is written under `games/<id>/<destination>/`, which the import owns: it deletes and rewrites that directory on every run, so nothing of the game's own belongs there. Godot's `.import` and `.uid` files there are kept across runs, and re-encoded audio comes out byte for byte the same, so an import run again changes only what changed in the Unity project or the settings. JSON dumps of the project's ScriptableObjects and of every converted scene tree go to `artifacts/<id>/unity_import/`, for the game's porting work (tables of items, crops and maps that the game turns into its own content). `--dry-run` lists what would be written.

After an import, run Godot's headless import (`godot --headless --import --path games/<id>`), since the import changes resources Godot caches. WAV files larger than `compress_audio_over_bytes`, or in a format Godot cannot import (ADPCM, for one), are re-encoded to Ogg Vorbis, which needs `ffmpeg` on `PATH`.

## What it converts

| Unity | Godot |
| --- | --- |
| Textures (`TextureImporter` single or multiple sprite mode) | The image, copied, and one `AtlasTexture` per sprite with its pivot (`metadata/pivot`, pixels from the region's top left) and nine-slice border (`metadata/border`, `Vector4i(left, top, right, bottom)`) |
| Tilemaps of a `Grid` | `TileMapLayer`s of one `TileSet` shared by the whole import, with flipped and rotated tiles as alternatives; tilemap colliders become a collision layer |
| GameObjects with `SpriteRenderer` | `Sprite2D`s, offset to the sprite's pivot, ordered by sorting layer and order (`z_index`), y-sorted by the layer `y_sort_layer` names |
| Box, circle, capsule, polygon and edge colliders | Collision shapes under a `StaticBody2D` (solid) or an `Area2D` named `Trigger` (trigger). A polygon path that crosses itself, which Unity accepts and Godot cannot split into convex parts, becomes its convex hull, with a warning |
| Prefabs and prefab instances, variants and nested prefabs | Scenes; instances keep their overrides |
| Animator controllers and animation clips | `AnimationLibrary` resources of sprite and offset tracks (`animations`); a folder of loose clips becomes one library (`clip_libraries`) |
| ScriptableObjects | JSON dumps under `artifacts/` (`data`) |
| MonoBehaviours the game names in `scripts` | Its own script attached, or its own scene instanced, with the fields it asks for |

## `unity_import` in `game.json`

| Key | What it is |
| --- | --- |
| `source` | The Unity project's root, relative to the game directory |
| `destination` | Where under the game the import writes (`game/unity`) |
| `pixels_per_unit` | Pixels to one Unity unit; a Unity position (x, y) lands at (x, -y) times this |
| `y_sort_layer` | The sorting layer whose objects y-sort with the player |
| `copy` | Asset folders (relative to `Assets/`) whose textures, audio and fonts are copied |
| `sprites` | Folders whose every sprite gets an `AtlasTexture` |
| `scenes` | Unity scene path (under `Assets/Scenes/`, no extension) to the name of the Godot scene, `scenes/<name>.tscn` |
| `prefabs` | Prefab folders to convert, each prefab to a scene of its own |
| `animations`, `clip_libraries` | Folders of animator controllers, and folders of loose clips to gather in one library each |
| `data` | Folders of ScriptableObjects to dump as JSON |
| `paths` | Renames of source folders in the destination, longest prefix first (`"Material Resources/Art": "art"`) |
| `skip_objects` | Names of GameObjects (with their children) left out of every scene: editor helpers, broken leftovers |
| `scripts` | The mapping of the project's MonoBehaviours, by class name, below |
| `id_maps` | Tables of the project's ids to the game's (`"items": {"1001": "axe"}`), for the `map:` and `asset:` kinds |
| `compress_audio_over_bytes` | WAV files larger than this become Ogg Vorbis |

A `scripts` entry either attaches a script of the game to the converted object (`"attach": "res://game/world/teleport.gd"`) or replaces the object with a scene of the game (`"scene": "res://..."`). `properties` maps the component's fields to the node's properties, `field: [property, kind]`, where a field may be nested (`"a.b"`) and the kind is one of `int`, `float`, `bool`, `string`, `id` (a `StringName`), `location` (a scene name to its location id), `position` (a Unity point to Godot pixels), `cell` (a Unity grid cell to a Godot one: (x, y) becomes (x, -y - 1)), `sprite`, `asset` (a referenced asset's file name), `asset:<map>` (that name looked up in an id map) or `map:<map>` (a value looked up in an id map; 0 and empty mean none). `set` gives fixed property values, `by_name` fixed values for objects whose name starts with a prefix. In prefabs an entry applies only when it attaches a script; its `prefab` entry, an entry of the same shape, replaces it there, and `"prefab": false` leaves prefabs alone.

## Then port the game

The import brings the art, the maps and the shapes of the old scenes; the game is still to be written. The way `games/mfarm/` was ported:

1. Read the old scripts and write down what the game does and which bugs it had (`games/mfarm/README.md` lists both).
2. Turn the dumped data into the game's content resources, listed in its content pack.
3. Write the game's systems in GDScript on the core: state in `WorldState` (or a save section of its own), content through `ContentDB`, input through `ControlAction`s and `InputLock`, travel through `WorldTravel` and locations.
4. Map the old MonoBehaviours onto those scripts in `scripts`, run the import again, and wrap each converted scene in a location scene of the game (spawn points, camera bounds, the player).
5. Translate every player-visible string (`node tools/check_localization.js`), write unit tests and a runtime smoke that plays the game end to end, and run `node tools/validate.js --game <id>`.
