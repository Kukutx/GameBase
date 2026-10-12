# Audio

GameBase has a data-driven audio routing layer, but the repository intentionally does not ship placeholder music or sound effects as if they were production content.

## Runtime architecture

- `GameAudio` is the foundation's audio service (`gamebase/core/audio/game_audio_service.gd`), an autoload every game registers.
- `AudioCueData` resources are listed in each game's content pack (`games/<id>/game/data/content.tres`) and resolved with `AudioCueData.find()`. A game maps events to cues in `GameDefinition.event_cues`.
- Music routes to the `Music` bus.
- Sound effects route to the `Sounds` bus.
- Master/Music/Sounds levels are persisted by `GameSettings` and already exposed in Settings.
- Missing or intentionally empty audio streams are safe no-ops: gameplay never depends on a sound successfully playing.
- Music crossfades: a new piece fades in over its cue's `fade_seconds` while the one before fades out on a second player.
- Music stacks: a location plays its `music_cue_id`; `GameAudio.push_music(layer, cue)` plays music over it until `pop_music(layer)`, and the music beneath then resumes where it stopped. The combat module's `FightState` pushes `CombatSettings.fight_music_cue_id` while a creature hunts the player (layer `fight`); `MiniGameHost` pushes a minigame's `MiniGameDefinition.music_cue_id` while it runs (layer `minigame`).
- Voices: up to `SFX_CHANNEL_COUNT` sounds heard everywhere alike and `POSITIONAL_CHANNEL_COUNT` heard from places play at once, each cue at most its `max_voices` times; past either, the oldest stops.
- Positional sounds: `GameAudio.play_cue_at(cue, position)` plays a sound from a place in the world, heard up to the cue's `hearing_distance` from the view's centre. An event cue of an event that carries `position: Vector2` (the items, lifesim and combat world events: a harvest, a mined rock, a hurt or defeated enemy, a finished machine) plays from there.
- Menu sounds: `GameDefinition.menu_focus_cue_id`, `menu_press_cue_id`, `menu_open_cue_id` and `menu_close_cue_id` sound when the focus moves with the keys or a gamepad (not with a click, the pointer or a menu focusing its first control), any button is pressed, and a menu opens or closes (`GameEvents.menu_opened`, `menu_closed`); of those asked for in one frame only the most telling plays.
- The content check reports an event, menu, fight or minigame cue that names no cue or one of the wrong kind (a sound where music belongs, or the reverse).

Gameplay systems should request stable cue IDs. They must not load audio files directly or depend on an audio filename.

## Stable cue IDs

Current SFX slots (Farm1; Ember Depths has the combat, shop and menu ones; Iron Banners the menu ones):

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
- `sfx_menu_focus`, `sfx_menu_press`, `sfx_menu_open` and `sfx_menu_close` (the menu sounds)

Current location music slots:

- `music_starter_town`
- `music_riverside_town`
- `music_harbor_town`
- `music_player_home`
- `music_old_mine`
- `music_fight` (Farm1 and Ember Depths: a fight)
- `music_camp` and `music_depths` (Ember Depths' camp and depths)
- `music_camp` (Iron Banners' camp and lookout, which share it, so it plays on between them) and `music_battle` (both of its battles)

A `WorldLocationData` may store a stable `music_cue_id` (each location of the three games does; a location without one plays no music); scene filenames are not used as music keys.

## Current content status

The cue resources are committed and validated, but their `stream` fields are intentionally empty. This means the current repository build remains silent until production-approved audio is supplied.

This is deliberate. Do not add generated beeps, temporary music, or unlicensed tracks merely to make the game non-silent.

## Adding production audio

1. Add distribution-approved audio files under a committed game-owned path such as `games/<id>/game/audio/music/` or `games/<id>/game/audio/sfx/`.
2. Keep raw purchased/source packs outside the distributable runtime tree unless their license explicitly permits redistribution in the shipped form.
3. Assign the imported `AudioStream` to the matching `games/<id>/game/data/audio/*.tres` cue.
4. Reuse an existing stable cue ID whenever the gameplay meaning is unchanged.
5. Add a new cue resource and list it in the content pack only when a genuinely new semantic sound event is needed.
6. Run `tools/validate.js` and release export verification.

Do not put audio file paths in farming, fishing, combat, NPC, shop, quest, or UI gameplay code. Those systems announce what happened on their module's `<Module>Events` autoload, and the game's `GameDefinition.event_cues` maps such an event, named `<Autoload>.<signal>` (`LifesimEvents.crop_harvested`), to a cue id; otherwise they call `GameAudio.play_cue(<stable_id>)`.

## Testing

`gamebase/core/test/test_audio_service.gd` and `test_audio_music.gd`, which every game runs, verify on in-memory streams (`gamebase/core/test/audio_fixture.gd`):

- a cue without a stream is a safe, silent request;
- sounds and music play on the correct bus;
- a cue's voices and the channels give way oldest first;
- a sound played at a place, or by an event that carries a position, is heard from there;
- the menu sounds play once a frame, the most telling;
- music crossfades, pushed music plays until popped and the music beneath resumes where it stopped;
- the content check reports cues of the wrong kind.

The combat module's `test_fight.gd` verifies a fight's start, calm and music; `test_minigame_host.gd` a minigame's music.

`games/farm1/test/unit/test_audio.gd` verifies:

- all current cue IDs are indexed;
- every playable location resolves a MUSIC cue;
- `Master`, `Music`, and `Sounds` buses exist;
- gameplay event mappings request stable cue IDs.
