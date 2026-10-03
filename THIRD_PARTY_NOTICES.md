# Third-party notices

GameBase release packages include software covered by the licenses below. The
full license and copyright files are distributed in the adjacent `licenses/`
directory.

## GameBase / upstream project foundation

The repository's root `LICENSE` is the project license currently carried by
GameBase. A copy is distributed as `licenses/GAMEBASE_LICENSE.txt`.

## Godot Engine

GameBase is built with Godot Engine. The shared build baseline is defined in
`.godot-version`. The synchronized legal-bundle version is recorded in
`licenses/GODOT_VERSION.txt` and must match that baseline.

Godot Engine is primarily licensed under the MIT license. Release packages
include the official license as `licenses/GODOT_LICENSE.txt` and the matching
official `COPYRIGHT.txt` as `licenses/GODOT_COPYRIGHT.txt`; the latter contains
the licensing information for third-party code distributed with the engine.

## Dialogue Manager

GameBase includes Dialogue Manager 4.1.0 by Nathan Hoad and contributors,
licensed under the MIT license. Its license is distributed as
`licenses/DIALOGUE_MANAGER_LICENSE.txt`.

## Development-only dependencies

GUT is used for automated tests and is explicitly excluded from release
resource packs.

## Locally licensed art

Raw purchased/local source art under `game/art/licensed/` is development-only
and is explicitly excluded from release resource packs. GameBase runtime
components fall back to committed project visuals when those local assets are
unavailable. Do not add those raw source files to release packages without a
separate license review.
