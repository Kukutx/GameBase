class_name SaveSlotSummary
extends RefCounted

## What a save slot holds, for slot pickers and support bundles
## (`GameSaveManager.get_slot_summary()`), told from the newer of its saves.

## The summary of `slot` when it holds no save of this build: `unreadable`
## when it has files all the same.
static func without_save(slot: int, unreadable: bool) -> Dictionary:
	return {"slot": slot, "exists": false, "recoverable": false, "unreadable": unreadable}

## The summary of `slot` from `candidate`, a save of this build as the save
## manager reads one ({"data", "source", "autosave"}), with what the game adds
## (`details`).
static func of(slot: int, candidate: Dictionary, details: PackedStringArray) -> Dictionary:
	var data: Dictionary = candidate["data"]
	var clock: Dictionary = data["clock"]
	var day := maxi(SaveValues.whole_number_or(clock.get("day", 1), 1), 1)
	var source := String(candidate["source"])
	# A save this build loads names a location of its content.
	var location := SavePlace.find_location(data)
	return {
		"slot": slot,
		"exists": true,
		"unreadable": false,
		"autosave": bool(candidate["autosave"]),
		"recoverable": source != "primary",
		"recovery_source": source,
		"version": GameSaveManager.SAVE_VERSION,
		"game_version": String(data.get("game_version", "")),
		"engine_version": String(data.get("engine_version", "")),
		"saved_at_unix": SaveValues.count(data.get("saved_at_unix_msec", 0)) / 1000,
		"location_id": String(location.id),
		"location_name": location.display_name,
		"play_seconds": GameSessionService.read_play_seconds(data),
		"day": day,
		"season": GameCalendar.current().get_season_name(day),
		"day_of_season": GameCalendar.current().get_day_of_season(day),
		"minute_of_day": clampi(SaveValues.whole_number_or(clock.get("minute_of_day", 0), 0), 0, GameClock.MINUTES_PER_DAY - 1),
		"details": details,
	}
