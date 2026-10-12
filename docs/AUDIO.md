# Audio

GameBase has a data-driven audio routing layer, but the repository intentionally does not ship placeholder music or sound effects as if they were production content.

## Runtime architecture

- `GameAudio` is the foundation's audio service (`gamebase/core/audio/game_audio_service.gd`), an autoload every game registers.
- `AudioCueData` resources are listed in each game's content pack (`games/<id>/game/data/content.tres`) and resolved with `AudioCueData.find()`. A game maps events to cues in `GameDefinition.event_cues`.
- Music routes to the `Music` bus.
- Sound effects route to the `Sounds` bus.
- Master/Music/Sounds levels are persisted by `GameSettings` and already exposed in Settings.
- Missing or intentionally empty audio streams are safe no-ops: gameplay never depends on a sound successfully playing.

Gameplay systems should request stable cue IDs. They must not load audio files directly or depend on an audio filename.

## Stable cue IDs

Current SFX slots (Farm1; Ember Depths has the combat and shop ones: `sfx_enemy_defeated`, `sfx_swing`, `sfx_hit`, `sfx_hurt`, `sfx_purchase` and `sfx_sale`):

- `sfx_pickup`
- `sfx_harvest`
- `sfx_gift`
- `sfx_fish_caught`
- `sfx_resource_mined`
- `sfx_enemy_defeated`
- `sfx_processing_complete`
- `sfx_tool_upgraded`
- `sfx_swing` (`CombatEvents.attack_swung`)
- `sfx_hit` (`CombatEvents.enemy_hurt`)
- `sfx_hurt` (`CombatEvents.player_hurt`)
- `sfx_purchase` (`ShopState.purchase_completed`)
- `sfx_sale` (`ShopState.sale_completed`)

Current location music slots:

- `music_starter_town`
- `music_riverside_town`
- `music_harbor_town`
- `music_player_home`
- `music_old_mine`

A `WorldLocationData` may store a stable `music_cue_id` (each Farm1 location does; a location without one plays no music); scene filenames are not used as music keys.

## Current content status

The cue resources are committed and validated, but their `stream` fields are intentionally empty. This means the current repository build remains silent until production-approved audio is supplied.

This is deliberate. Do not add generated beeps, temporary music, or unlicensed tracks merely to make the game non-silent.

## Adding production audio

1. Add distribution-approved audio files under a committed game-owned path such as `games/<id>/game/audio/music/` or `games/<id>/game/audio/sfx/`.
2. Keep raw purchased/source packs outside the distributable runtime tree unless their license explicitly permits redistribution in the shipped form.
3. Assign the imported `AudioStream` to the matching `games/farm1/game/data/audio/*.tres` cue.
4. Reuse an existing stable cue ID whenever the gameplay meaning is unchanged.
5. Add a new cue resource and list it in the content pack only when a genuinely new semantic sound event is needed.
6. Run `tools/validate.js` and release export verification.

Do not put audio file paths in farming, fishing, combat, NPC, shop, quest, or UI gameplay code. Those systems announce what happened on their module's `<Module>Events` autoload, and the game's `GameDefinition.event_cues` maps such an event, named `<Autoload>.<signal>` (`LifesimEvents.crop_harvested`), to a cue id; otherwise they call `GameAudio.play_cue(<stable_id>)`.

## Testing

`gamebase/core/test/test_audio_service.gd`, which every game runs, verifies:

- a cue without a stream is a safe, silent request;
- injected in-memory WAV streams play on the correct bus.

`games/farm1/test/unit/test_audio.gd` verifies:

- all current cue IDs are indexed;
- every playable location resolves a MUSIC cue;
- `Master`, `Music`, and `Sounds` buses exist;
- gameplay event mappings request stable cue IDs.
