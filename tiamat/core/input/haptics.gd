class_name Haptics
extends RefCounted

## Shakes what the player holds, so a blow or a catch is felt as well as heard:
## the gamepad in use, or the phone or tablet the player plays by touch
## (Android, and a browser on one). A keyboard and mouse feel nothing, and
## nothing shakes once the player turns vibration off (`GameSettings.vibration`).
## A sound shakes as it plays when its cue says how hard (`AudioCueData.rumble`),
## so a game feels its blows by its content; `pulse()` shakes for anything else.

## How hard a pulse must be for a gamepad's heavy motor to join its light one:
## a tap is a buzz, a blow a thump.
const HEAVY_FROM := 0.5

## Whether the player holds something that shakes: a gamepad, or a phone or
## tablet (`InputPromptService.starts_on_touch()`). The settings offer
## vibration then.
static func is_offered() -> bool:
	return InputPromptService.starts_on_touch() or not Input.get_connected_joypads().is_empty()

## Shakes the player's gamepad or phone at `strength`, from 0 to 1, for
## `seconds`; whether anything shook.
static func pulse(strength: float, seconds: float) -> bool:
	var power := clampf(strength, 0.0, 1.0)
	if power <= 0.0 or seconds <= 0.0 or not GameSettings.vibration:
		return false
	var gamepad := InputPrompts.get_gamepad_in_use()
	if gamepad >= 0:
		Input.start_joy_vibration(gamepad, power, maxf(power - HEAVY_FROM, 0.0) / (1.0 - HEAVY_FROM), seconds)
		return true
	if InputPrompts.using_touch:
		Input.vibrate_handheld(maxi(roundi(seconds * 1000.0), 1), power)
		return true
	return false
