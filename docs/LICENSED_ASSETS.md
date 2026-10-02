# Local licensed art

`game/art/licensed/` is intentionally excluded from Git. The local project can use licensed third-party PNG files at runtime, but their raw source files must not be redistributed through this repository.

## GandalfHardcore

Current local packs used by GameBase:

- Farming Tiles and Crops 32x32
- House Asset Pack 32x32
- Pixel Art Village Houses tiles
- Farm Animals
- Slime Enemy

The readmes shipped with these packs permit use and modification in commercial/non-commercial video games and projects while prohibiting resale, repackaging, redistribution, AI training, NFT/Web3 usage, game-development-tool redistribution, and printed-material usage.

Source archives on the owner's workstation are under `A:\Project\Godot\Asset\GandalfHardcore`.

## Craftpix Free Top-Down Roguelike Game Kit

GameBase uses only selected directional character strips from the local archive:

`A:\Project\Godot\Asset\参考\craftpix-net-436971-free-top-down-roguelike-game-kit-pixel-art.zip`

Used runtime strips:

- Character 1: Down/Up/Side Idle + Walk
- Character 2: Down/Up/Side Idle + Walk

Craftpix's current Freebie license permits personal/commercial projects and distribution of games containing the assets, but prohibits redistribution of the source art files themselves. Therefore these PNG strips remain under the Git-ignored `game/art/licensed/` tree and are never committed as repository assets.

## Restore local assets

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/sync_licensed_assets.ps1
```

The script restores the selected runtime PNGs from the owner's local source archives.

Scenes/components using licensed art must degrade cleanly when the local files are absent:

- `LicensedArtSprite` hides itself when a texture is unavailable.
- `LicensedTerrainLayer` hides itself and leaves the fallback terrain visible.
- `DirectionalActorVisual` uses the polygon fallback when directional character strips are unavailable.

This keeps the project runnable and testable without redistributing third-party source artwork.
