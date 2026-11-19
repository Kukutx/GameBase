# Third-party notices

Release packages of the games built on Tiamat include software covered by
the licenses below. The full license and copyright files are distributed in the adjacent `licenses/`
directory.

## Tiamat / upstream project foundation

The repository's root `LICENSE` is the project license currently carried by
Tiamat. A copy is distributed as `licenses/TIAMAT_LICENSE.txt`.

## Godot Engine

Tiamat is built with Godot Engine. The shared build baseline is defined in
`.godot-version`. The synchronized legal-bundle version is recorded in
`licenses/GODOT_VERSION.txt` and must match that baseline.

Godot Engine is primarily licensed under the MIT license. Release packages
include the official license as `licenses/GODOT_LICENSE.txt` and the matching
official `COPYRIGHT.txt` as `licenses/GODOT_COPYRIGHT.txt`; the latter contains
the licensing information for third-party code distributed with the engine.

## Dialogue Manager

Games that use the `npc_social` module include Dialogue Manager 4.1.0 by Nathan
Hoad and contributors, licensed under the MIT license. Its license is distributed as
`licenses/DIALOGUE_MANAGER_LICENSE.txt`.

## Noto Sans SC

Every game shows its text in Noto Sans SC (`tiamat/core/ui/fonts/`) unless its
theme names another font. The font is cut down to Latin, Chinese punctuation,
the characters of GB 2312 and those the games use (`tools/subset_font.js`). It is
Copyright 2014-2021 Adobe, with Reserved Font Name 'Source', licensed under the
SIL Open Font License 1.1, which is distributed as
`licenses/NOTO_SANS_SC_LICENSE.txt`.

## MFarm's art, sounds and fonts

MFarm (`games/mfarm/`) carries over everything its Unity predecessor
MFarmDemo shipped, under `games/mfarm/game/unity/`:

- the "Fantastic Farm RPG game assets" (characters, maps, buildings, items,
  crops, trees, the interface) and the music and sounds, as provided with the
  Unity Learn China MFarm course (https://learn.u3d.cn/tutorial/MFarmCourse);
- the Fantasy Cursor Pack;
- the fonts GNU Unifont 14.0.01 (the interface font, licensed under the
  GNU GPL 2 or later with the font embedding exception, or the SIL Open Font
  License 1.1), Chusung and Gongfan.

Their terms are those their authors set; check them before releasing MFarm
outside of personal use.

## Development-only dependencies

GUT is used for automated tests and is explicitly excluded from release
resource packs.

## Locally licensed art

Raw purchased/local source art under a game's `game/art/licensed/` is development-only
and is explicitly excluded from release resource packs. Tiamat runtime
components fall back to committed project visuals when those local assets are
unavailable. Do not add those raw source files to release packages without a
separate license review.
