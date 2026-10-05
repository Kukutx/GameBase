# GameBase domain rules

This file holds the domain invariants of the game base. Generic engineering rules are in `.agents/rules/project.md`; repository layout and tool entry points are in `.agents/rules/project-profile.md`.

## Base and derived games

- GameBase is a base. Rules here protect what a derived game and its players rely on: stable ids, save compatibility, the service boundaries and the data-driven content pipeline. Content that ships with the base (towns, crops, NPCs, quests) is example content; changing it is allowed, breaking the mechanisms that carry it is not.
- A capability is part of the base only when it has a real consumer in the base. Do not add placeholder systems, compatibility shells or hooks for a hypothetical derived game.
- Code or data that is explicitly registered as reserved for later (an empty audio cue stream, a location without music, the optional AI dialogue layer) is not dead code and is not removed in a cleanup.

## Content and ids

- Production content is registered in `game/data/content_manifest.tres` and resolved through `ContentDB`. Do not add scattered hard-coded resource-path dictionaries.
- Ids are `StringName` values that never change once content has shipped: item, crop, NPC, quest, location, spawn, audio cue and the others. A display name can change; an id cannot. Removing content must degrade safely for saves that still reference it instead of blocking play or silently deleting player value.
- Rewards that were promised (mail attachments, project completion, archive milestones, blocked quest completion) are snapshotted when promised, so a later rebalance cannot change what the player was promised.

## Services and addons

- Wrap heavy or replaceable systems behind game-owned interfaces. Save data and core domain models do not depend directly on a third-party addon.
- Gameplay state lives in the autoload services. A scene is a presentation of that state and can be reloaded at any time.
- NPC authored dialogue and the later local-AI dialogue share `ConversationService`, `NpcContext` and `NpcMemory`. Model or provider code never owns gameplay state or save data.
- Microverse is a design reference for AI and NPC behaviour. A behaviour-tree addon such as LimboAI is introduced only when NPC behaviour complexity justifies it, not in advance.

## Save compatibility

- Published saves keep loading. A change to the save schema goes through `SaveMigration`; details and the checklist are in `.agents/rules/save.md`.
- A save from a newer build is never overwritten, rotated or "repaired" by an older build; deleting a slot is the only destructive path and it is explicit.

## Audio

- Gameplay audio goes through the game-owned `GameAudio` service and `AudioCueData` resources with stable cue ids registered in `ContentDB`. Gameplay systems do not load music or sound files by path.
- An empty cue stream is valid while production audio is pending. Do not ship generated beeps, temporary music or unlicensed tracks merely to avoid silence. Details: `docs/AUDIO.md`.

## World travel

- Travel uses stable Location ids and Spawn ids through `WorldTravel`. Travel by scene path remains only as a compatibility escape hatch; new code does not use it.

## Player-visible text

- Every player-visible string has a non-empty Simplified Chinese entry, and dynamic ids and save keys stay untranslated. The rules and the gate are in `.agents/rules/localization.md` and `docs/LOCALIZATION.md`.

## Licensed art

- Purchased raw art under `game/art/licensed/` is local-only and Git-ignored. Never commit or redistribute those source files; `node tools/sync_licensed_assets.js` restores them on the owner's machine.
- Every scene stays runnable without those files: `LicensedArtSprite` and `LicensedTerrainLayer` hide themselves and `DirectionalActorVisual` falls back to polygons. A change that makes a scene depend on a licensed file being present breaks the open-source build. Details: `docs/LICENSED_ASSETS.md`.

## Diagnostics and privacy

- Support bundles are created only on the player's explicit request and contain sanitized logs, runtime and settings metadata and save-slot summaries. Raw saves, the raw settings file, licensed source art and absolute user paths are never included. Details: `docs/SUPPORT.md`.
