# Local licensed art

A game's `game/art/licensed/` is excluded from Git (`games/*/game/art/licensed/` in `.gitignore`). A game can use licensed third-party PNG files at runtime, but their raw source files must not be redistributed through this repository.

## Where the packs are listed

Each game that uses licensed art lists it under `licensed_art` in its `games/<id>/game.json`:

- `sources`: the name and the location on the owner's workstation of each source (a folder of archives or one archive);
- `packs`: for each pack, its source, the archive or folder inside it, the files to take (a glob such as `*.png`, or an explicit list) and the destination under `game/art/licensed/`.

On the owner's workstation, restore a game's selected runtime files with:

```text
node tools/sync_licensed_assets.js --game <id>
```

`--source <name>=<path>` overrides where one source lives on the current machine.

## Farm1

### GandalfHardcore

Farm1 uses these packs:

- Farming Tiles and Crops 32x32
- House Asset Pack 32x32
- Pixel Art Village Houses tiles
- Farm Animals
- Slime Enemy

The readmes shipped with these packs permit use and modification in commercial and non-commercial video games and projects while prohibiting resale, repackaging, redistribution, AI training, NFT/Web3 usage, game-development-tool redistribution and printed-material usage.

### Craftpix Free Top-Down Roguelike Game Kit

Farm1 uses only the directional character strips of characters 1 to 3 (down, up and side; idle, walk, attack, hurt and death) from the local archive.

Craftpix's current Freebie license permits personal and commercial projects and distribution of games containing the assets, but prohibits redistribution of the source art files themselves. These strips therefore stay under the Git-ignored `games/farm1/game/art/licensed/` tree and are never committed.

## Release packs and fallbacks

Release resource packs exclude `game/art/licensed/` through each game's `export_presets.cfg`, even when that directory exists on the build machine. `tools/verify_export_contents.js` loads each produced PCK and fails the export if the licensed tree is present.

Scenes and components that use licensed art degrade cleanly when the local files are absent:

- `LicensedArtSprite` hides itself when a texture is unavailable.
- `LicensedTerrainLayer` hides itself and leaves the fallback terrain visible.
- `DirectionalActorVisual` uses the polygon fallback when directional character strips are unavailable.

This keeps every game runnable and testable without redistributing third-party source artwork.
