# GameBase domain rules

This file holds the domain invariants of the game base. Generic engineering rules are in `.agents/rules/project.md`; repository layout and tool entry points are in `.agents/rules/project-profile.md`.

## Foundation and games

- `gamebase/` is the foundation every game in `games/` builds on. Rules here protect what the games and their players rely on: stable ids, the save format, the service boundaries and the data-driven content pipeline. A game's content (Farm1's towns, crops, NPCs and quests) belongs to that game; changing it is allowed, breaking the mechanisms that carry it is not.
- A capability belongs in the foundation when it is not specific to one game and a registered game uses it; it then lives once in `gamebase/` and is never copied into a game. What only one game needs stays in that game's `game/`. Do not add placeholder systems, compatibility shells or hooks for a hypothetical future game.
- Nothing in `gamebase/`, scripts, scenes and resources alike, names a game's ids: its content ids, nor the ids its scenes give to locations, spawn points, housings, containers and the like. A module reads them from a slot the game fills (an exported property set in the game's scene, a field of the game's data, `GameDefinition`) and owns only its own vocabulary, such as the tool actions it responds to (`FarmPlot.TILL_ACTION`, `MeleeAttack.TOOL_ACTION`). `tools/check_layers.js` enforces this.
- Code or data that is explicitly registered as reserved for later (an empty audio cue stream, a location without music, the optional AI dialogue layer) is not dead code and is not removed in a cleanup.

## Content and ids

- A game's production content is listed in its content pack (`games/<id>/game/data/content.tres`) and resolved through `ContentDB`, by the content classes' `find()`. Do not add scattered hard-coded resource-path dictionaries.
- Ids are `StringName` values that never change once content has shipped: item, crop, NPC, quest, location, spawn, audio cue and the others. A display name can change; an id cannot. A save that references removed content loads without it.
- Rewards that were promised (mail attachments, project completion, archive milestones, blocked quest completion) are snapshotted when promised, so a later rebalance cannot change what the player was promised.

## Services and addons

- Wrap heavy or replaceable systems behind game-owned interfaces. Save data and core domain models do not depend directly on a third-party addon.
- Gameplay state lives in the autoload services. A scene is a presentation of that state and can be reloaded at any time.
- NPC authored dialogue and the later local-AI dialogue share `ConversationService`, `NpcContext` and `NpcMemory`. Model or provider code never owns gameplay state or save data.
- Microverse is a design reference for AI and NPC behaviour. A behaviour-tree addon such as LimboAI is introduced only when NPC behaviour complexity justifies it, not in advance.

## Save format

- The project is experimental: there is one save format and no compatibility code. A change to what a save contains raises `SAVE_VERSION`, and saves of other versions no longer load; details and the checklist are in `.agents/rules/save.md`.
- Deleting a slot is the only destructive path and it is explicit.

## Audio

- Gameplay audio goes through the game-owned `GameAudio` service and `AudioCueData` resources with stable cue ids registered in `ContentDB`. Gameplay systems do not load music or sound files by path.
- An empty cue stream is valid while production audio is pending. Do not ship generated beeps, temporary music or unlicensed tracks merely to avoid silence. Details: `docs/AUDIO.md`.

## World travel

- Travel uses stable Location ids and Spawn ids through `WorldTravel.travel_to()` (with the fade) and `go_to()` (at once); there is no travel by scene path.

## Player-visible text

- Every player-visible string has a non-empty Simplified Chinese entry, and dynamic ids and save keys stay untranslated. The rules and the gate are in `.agents/rules/localization.md` and `docs/LOCALIZATION.md`.

## Licensed art

- Purchased raw art under a game's `game/art/licensed/` is local-only and Git-ignored. Never commit or redistribute those source files; `node tools/sync_licensed_assets.js --game <id>` restores the packs listed under `licensed_art` in that game's `game.json` on the owner's machine.
- Every scene stays runnable without those files: `LicensedArtSprite` and `LicensedTerrainLayer` hide themselves and `DirectionalActorVisual` falls back to polygons. A change that makes a scene depend on a licensed file being present breaks the open-source build. Details: `docs/LICENSED_ASSETS.md`.

## Diagnostics and privacy

- Support bundles are created only on the player's explicit request and contain sanitized logs, runtime and settings metadata and save-slot summaries. Raw saves, the raw settings file, licensed source art and absolute user paths are never included. Details: `docs/SUPPORT.md`.
