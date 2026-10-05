class_name GameSaveManager
extends Node

signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)
signal active_slot_changed(slot: int)

const SAVE_VERSION := 8
const SLOT_COUNT := 3
const DEFAULT_SAVE_PATH := "user://savegame.json"
const DEFAULT_TEMP_PATH := "user://savegame.tmp"
const DEFAULT_BACKUP_PATH := "user://savegame.bak"

var active_slot := 1
var save_path := DEFAULT_SAVE_PATH
var temp_path := DEFAULT_TEMP_PATH
var backup_path := DEFAULT_BACKUP_PATH
var _preserve_newer_primary := false

func _ready() -> void:
	select_slot(active_slot)

func select_slot(slot: int) -> void:
	var resolved := clampi(slot, 1, SLOT_COUNT)
	active_slot = resolved
	var paths := get_slot_paths(resolved)
	save_path = String(paths["save"])
	temp_path = String(paths["temp"])
	backup_path = String(paths["backup"])
	_preserve_newer_primary = false
	active_slot_changed.emit(active_slot)

func get_slot_paths(slot: int) -> Dictionary:
	var resolved := clampi(slot, 1, SLOT_COUNT)
	if resolved == 1:
		return {
			"save": DEFAULT_SAVE_PATH,
			"temp": DEFAULT_TEMP_PATH,
			"backup": DEFAULT_BACKUP_PATH,
		}
	var stem := "user://savegame_slot%d" % resolved
	return {
		"save": stem + ".json",
		"temp": stem + ".tmp",
		"backup": stem + ".bak",
	}

func has_save(slot: int = -1) -> bool:
	if slot > 0:
		var paths := get_slot_paths(slot)
		return not _read_best_slot_snapshot(String(paths["save"]), String(paths["temp"]), String(paths["backup"])).is_empty()
	return not _read_best_slot_snapshot(save_path, temp_path, backup_path).is_empty()

func get_slot_summary(slot: int) -> Dictionary:
	var paths := get_slot_paths(slot)
	var primary_path := String(paths["save"])
	var temp_path_for_slot := String(paths["temp"])
	var backup_path_for_slot := String(paths["backup"])
	var loadable := _read_best_loadable_slot_snapshot(primary_path, temp_path_for_slot, backup_path_for_slot)
	var candidate := loadable if not loadable.is_empty() else _read_best_slot_snapshot(primary_path, temp_path_for_slot, backup_path_for_slot)
	if candidate.is_empty():
		return {
			"slot": clampi(slot, 1, SLOT_COUNT),
			"exists": false,
			"loadable": false,
			"recoverable": false,
		}
	var summary := _build_slot_summary(slot, candidate)
	summary["loadable"] = not loadable.is_empty()
	summary["newer_primary_preserved"] = bool(candidate.get("newer_primary_preserved", false))
	return summary

func _build_slot_summary(slot: int, candidate: Dictionary) -> Dictionary:
	var stored_data: Dictionary = candidate.get("data", {}) if candidate.get("data", {}) is Dictionary else {}
	var stored_version := _snapshot_version(stored_data)
	# Slot cards should describe the state the player will actually get after
	# loading, including defaults introduced by migrations for legacy saves.
	var data := SaveMigration.migrate(stored_data, SAVE_VERSION) if stored_version <= SAVE_VERSION else stored_data
	var clock: Dictionary = data.get("clock", {}) if data.get("clock", {}) is Dictionary else {}
	var player_state: Dictionary = data.get("player_state", {}) if data.get("player_state", {}) is Dictionary else {}
	var day := maxi(_safe_int(clock.get("day", 1), 1), 1)
	var recovery_source := String(candidate.get("source", "primary"))
	return {
		"slot": clampi(slot, 1, SLOT_COUNT),
		"exists": true,
		"recoverable": recovery_source != "primary",
		"recovery_source": recovery_source,
		"version": stored_version,
		"future_version": stored_version > SAVE_VERSION,
		"game_version": _safe_string(data.get("game_version", "")),
		"engine_version": _safe_string(data.get("engine_version", "")),
		"saved_at_unix": _safe_int(data.get("saved_at_unix", 0), 0),
		"scene": _safe_string(data.get("scene", "")),
		"day": day,
		"season": GameClock.get_season_name_for_day(day),
		"day_of_season": posmod(day - 1, GameClock.DAYS_PER_SEASON) + 1,
		"minute_of_day": clampi(_safe_int(clock.get("minute_of_day", 8 * 60), 8 * 60), 0, GameClock.MINUTES_PER_DAY - 1),
		"money": maxi(_safe_int(player_state.get("money", 500), 500), 0),
	}

func delete_slot(slot: int) -> bool:
	var paths := get_slot_paths(slot)
	var success := _delete_paths([String(paths["save"]), String(paths["temp"]), String(paths["backup"])])
	if clampi(slot, 1, SLOT_COUNT) == active_slot:
		_preserve_newer_primary = false
	return success

func delete_save() -> bool:
	_preserve_newer_primary = false
	return _delete_paths([save_path, temp_path, backup_path])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		load_game()
		get_viewport().set_input_as_handled()

func get_save_block_reason() -> String:
	if WorldTravel.is_traveling():
		return tr("Cannot save while traveling")
	var scene := get_tree().current_scene
	if scene == null or ContentDB.get_location_for_scene(scene.scene_file_path) == null:
		return tr("Save from a playable location")
	if get_tree().get_first_node_in_group("player") == null:
		return tr("Cannot save without the player")
	if FishingState.is_active():
		return tr("Finish fishing before saving")
	return ""

func save_game(allow_unregistered_scene: bool = false) -> bool:
	return _save_game_internal(allow_unregistered_scene, true)

func save_game_silent(allow_unregistered_scene: bool = false) -> bool:
	return _save_game_internal(allow_unregistered_scene, false)

func _save_game_internal(allow_unregistered_scene: bool, emit_result: bool) -> bool:
	if not allow_unregistered_scene:
		var block_reason := get_save_block_reason()
		if not block_reason.is_empty():
			_emit_save_result(emit_result, false, block_reason)
			return false
	var snapshot := build_snapshot()
	if not _write_dictionary(temp_path, snapshot):
		_emit_save_result(emit_result, false, tr("Could not write temporary save file"))
		return false
	if _should_preserve_newer_primary():
		return _finalize_compatible_backup_save(emit_result)

	# Keep the last valid primary as a backup before replacing it. Slot 1 keeps
	# the legacy savegame.json path, so existing saves remain compatible.
	if FileAccess.file_exists(save_path):
		var existing := _read_dictionary(save_path)
		# Never replace a known-good backup with a primary that is merely valid
		# JSON but fails the version-aware structural checks. A damaged primary
		# should be overwritten by the new save while the last recovery point stays
		# intact.
		if _is_snapshot_usable(existing):
			if not _write_dictionary(backup_path, existing):
				_emit_save_result(emit_result, false, tr("Could not create save backup"))
				return false

	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var save_absolute := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_absolute)
	var rename_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
	if rename_error != OK:
		# Restore the last known-good backup if finalization failed.
		var backup := _read_dictionary(backup_path)
		if not backup.is_empty():
			_write_dictionary(save_path, backup)
		_emit_save_result(emit_result, false, tr("Could not finalize save file (%d)") % rename_error)
		return false

	_emit_save_result(emit_result, true, tr("Game saved · Slot %d") % active_slot)
	return true

func _emit_save_result(enabled: bool, success: bool, message: String) -> void:
	if enabled:
		save_completed.emit(success, message)

func _should_preserve_newer_primary() -> bool:
	# Detect a newer primary on every save, not only after this session already
	# loaded a compatible backup. Starting a new game in an older build must not
	# silently rotate/overwrite a future-format primary; explicit slot deletion is
	# the destructive opt-in path.
	var primary := _read_dictionary(save_path)
	if _is_snapshot_usable(primary) and _snapshot_version(primary) > SAVE_VERSION:
		_preserve_newer_primary = true
		return true
	_preserve_newer_primary = false
	return false

func _finalize_compatible_backup_save(emit_result: bool = true) -> bool:
	var previous_backup := _read_dictionary(backup_path)
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	var rename_error := DirAccess.rename_absolute(temp_absolute, backup_absolute)
	if rename_error != OK:
		if not previous_backup.is_empty():
			_write_dictionary(backup_path, previous_backup)
		_emit_save_result(emit_result, false, tr("Could not update compatible backup (%d)") % rename_error)
		return false
	_emit_save_result(emit_result, true, tr("Game saved to compatible backup · newer primary preserved"))
	return true

func load_game() -> bool:
	if WorldTravel.is_traveling():
		load_completed.emit(false, tr("Cannot load while traveling"))
		return false
	var candidate := _read_best_loadable_slot_snapshot(save_path, temp_path, backup_path)
	if candidate.is_empty():
		var unavailable := _read_best_slot_snapshot(save_path, temp_path, backup_path)
		if not unavailable.is_empty() and _snapshot_version(unavailable["data"] as Dictionary) > SAVE_VERSION:
			load_completed.emit(false, tr("Save file is from a newer game version"))
		else:
			load_completed.emit(false, tr("No save file yet"))
		return false
	var data: Dictionary = candidate["data"]
	data = SaveMigration.migrate(data, SAVE_VERSION)
	var applied: bool = await apply_snapshot(data)
	if not applied:
		load_completed.emit(false, tr("Save references an unavailable scene"))
		return false

	var recovery_source := String(candidate.get("source", "primary"))
	var recovered := recovery_source != "primary"
	var preserve_primary := bool(candidate.get("newer_primary_preserved", false))
	if recovery_source == "temp":
		# Temp may represent either the old crash window after primary removal or a
		# newer fully-written snapshot left just before the old primary was removed.
		# When replacing a still-valid compatible primary, preserve that primary as
		# backup first; only delete temp after the durable promotion succeeds.
		var repaired := false
		if preserve_primary:
			repaired = _write_dictionary(backup_path, data)
		else:
			var existing_primary := _read_dictionary(save_path)
			var can_promote := true
			if _is_snapshot_usable(existing_primary) and _snapshot_version(existing_primary) <= SAVE_VERSION:
				can_promote = _write_dictionary(backup_path, existing_primary)
			if can_promote:
				repaired = _write_dictionary(save_path, data)
		if repaired:
			_delete_paths([temp_path])
	elif recovery_source == "backup" and not preserve_primary:
		# Repair a damaged/missing primary after successful backup recovery.
		_write_dictionary(save_path, data)
	_preserve_newer_primary = recovered and preserve_primary
	if recovered and preserve_primary and recovery_source == "temp":
		load_completed.emit(true, tr("Loaded Slot %d from compatible temporary save · newer primary preserved") % active_slot)
	elif recovered and preserve_primary:
		load_completed.emit(true, tr("Loaded Slot %d from compatible backup · newer primary preserved") % active_slot)
	elif recovery_source == "temp":
		load_completed.emit(true, tr("Recovered Slot %d from temporary save") % active_slot)
	elif recovered:
		load_completed.emit(true, tr("Recovered Slot %d from backup") % active_slot)
	else:
		load_completed.emit(true, tr("Game loaded · Slot %d") % active_slot)
	return true

func build_snapshot() -> Dictionary:
	var saved_at := Time.get_unix_time_from_system()
	var scene_path := ""
	if get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	var location_id := ""
	var location := ContentDB.get_current_location(get_tree())
	if location != null:
		location_id = String(location.id)
	var player_data: Dictionary = {}
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		player_data = {
			"x": player.global_position.x,
			"y": player.global_position.y,
		}
	return {
		"version": SAVE_VERSION,
		"game_version": String(ProjectSettings.get_setting("application/config/version", "unknown")),
		"engine_version": String(Engine.get_version_info().get("string", "unknown")),
		"slot": active_slot,
		"saved_at_unix": saved_at,
		"saved_at_unix_msec": int(round(saved_at * 1000.0)),
		"scene": scene_path,
		"location_id": location_id,
		"clock": WorldClock.to_save_data(),
		"weather": WeatherState.to_save_data(),
		"inventory": InventoryState.to_save_data(),
		"player_state": PlayerState.to_save_data(),
		"world": WorldState.to_save_data(),
		"relationships": RelationshipState.to_save_data(),
		"npc_memory": NpcMemory.to_save_data(),
		"quests": QuestState.to_save_data(),
		"skills": Skills.to_save_data(),
		"buffs": BuffState.to_save_data(),
		"shipping": ShippingState.to_save_data(),
		"fishing": FishingState.to_save_data(),
		"player": player_data,
	}

func apply_snapshot(data: Dictionary) -> bool:
	# Resolve and preload the destination before mutating any global service. A
	# malformed current-format Location ID or non-PackedScene target must fail
	# without partially replacing the currently running session.
	var destination := _resolve_snapshot_destination(data)
	if bool(destination.get("invalid", false)):
		return false
	var target_scene := String(destination.get("scene_path", ""))
	var target_packed: PackedScene = null
	if not target_scene.is_empty():
		target_packed = ResourceLoader.load(target_scene) as PackedScene
		if target_packed == null:
			return false

	# Restore global truth before instantiating the saved scene. Persistent scene
	# components read these services in _ready(), so this ordering prevents stale
	# farm plots, pickups, NPC labels, HUD values, and new-game initialization.
	var weather_data: Variant = data.get("weather", {})
	if weather_data is Dictionary:
		WeatherState.load_save_data(weather_data)
	# Shipping must restore its saved day marker before WorldClock emits a
	# day_changed signal, otherwise loading an older/newer save could pay twice.
	var shipping_data: Variant = data.get("shipping", {})
	if shipping_data is Dictionary:
		ShippingState.load_save_data(shipping_data)
	var clock_data: Variant = data.get("clock", {})
	if clock_data is Dictionary:
		ShippingState.reconcile_loaded_day(_safe_int(clock_data.get("day", 1), 1))
		WorldClock.load_save_data(clock_data)
	var buff_data: Variant = data.get("buffs", {})
	if buff_data is Dictionary:
		BuffState.load_save_data(buff_data)
	var inventory_data: Variant = data.get("inventory", {})
	if inventory_data is Dictionary:
		InventoryState.load_save_data(inventory_data)
	var player_state_data: Variant = data.get("player_state", {})
	PlayerState.load_save_data(player_state_data if player_state_data is Dictionary else {})
	var world_data: Variant = data.get("world", {})
	if world_data is Dictionary:
		WorldState.load_save_data(world_data)
	var relationship_data: Variant = data.get("relationships", {})
	if relationship_data is Dictionary:
		RelationshipState.load_save_data(relationship_data)
	var npc_memory_data: Variant = data.get("npc_memory", {})
	if npc_memory_data is Dictionary:
		NpcMemory.load_save_data(npc_memory_data)
	var quest_data: Variant = data.get("quests", {})
	if quest_data is Dictionary and not quest_data.is_empty():
		QuestState.load_save_data(quest_data)
	else:
		# Saves from before the quest system (or repaired saves missing the section)
		# must not inherit the currently running session or load into a questless
		# dead-end. Rebuild only the data-declared automatic entry quests.
		QuestState.reset_new_game()
	var skill_data: Variant = data.get("skills", {})
	Skills.load_save_data(skill_data if skill_data is Dictionary else {})
	var fishing_data: Variant = data.get("fishing", {})
	if fishing_data is Dictionary:
		FishingState.load_save_data(fishing_data)
	QuestState.reconcile_loaded_progress()
	# Town-project completion is derived from contributed materials and can become
	# newly satisfiable after a content update changes requirements. Repair that
	# derived state only after the whole save snapshot is restored, then reapply
	# current unlock flags before mail/event backfill runs.
	TownProjects.reconcile_loaded_progress()
	# Preserve paid housing capacity independently from expansion resource IDs so
	# future content renames/removals cannot shrink an old save's coop/barn.
	FarmExpansionState.reconcile_loaded_state()
	# Collection readiness is also derived from WorldState. Re-evaluate it after
	# loading so newly-ready or legacy-ready milestones freeze their promised
	# rewards before the player can claim them.
	CollectionMilestones.reconcile_loaded_state()

	# WorldClock is restored before WorldState so services can preserve their
	# saved day markers, but calendar flags live inside WorldState. Rebuild them
	# once the world snapshot is in place so an old save loaded during a festival
	# cannot keep EventState active while losing event:<id>:active flags.
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day, true)

	# Content updates can introduce new letters whose requirements were already
	# satisfied in an older save. Refresh only after every prerequisite service
	# has been restored so those letters arrive immediately on load instead of
	# waiting for the next day or another unrelated state change.
	MailState.refresh_deliveries()

	# Always reload the prevalidated playable scene, even when it is already open.
	# Save v8 stores a stable Location ID so scene-file renames do not invalidate
	# an otherwise healthy long-term save. Exact scene matches can restore the
	# saved coordinates; remapped/fallback scenes use a stable spawn instead.
	if target_packed != null:
		data["scene"] = target_scene
		var resolved_location_id := String(destination.get("location_id", ""))
		if not resolved_location_id.is_empty():
			data["location_id"] = resolved_location_id
		var change_error := get_tree().change_scene_to_packed(target_packed)
		if change_error != OK:
			return false
		await get_tree().scene_changed
		await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var player_data: Variant = data.get("player", {})
	var can_restore_position := false
	if player_data is Dictionary and player_data.has("x") and player_data.has("y"):
		can_restore_position = _is_numeric(player_data["x"]) and _is_numeric(player_data["y"])
	if player != null and bool(destination.get("use_saved_position", false)) and can_restore_position:
		player.global_position = Vector2(float(player_data["x"]), float(player_data["y"]))
	elif player != null:
		if not _apply_player_spawn(player, StringName(String(destination.get("spawn_id", "")))):
			# Do not carry coordinates from a removed scene or malformed save into a
			# different layout. Stable spawn is the safe fallback.
			data["player"] = {}
	if player != null:
		data["player"] = {"x": player.global_position.x, "y": player.global_position.y}
	_sync_snapshot_runtime_sections(data)
	return true

func _resolve_snapshot_destination(data: Dictionary) -> Dictionary:
	var saved_scene := String(data.get("scene", ""))
	var saved_location_id := StringName(String(data.get("location_id", "")))
	var version := _snapshot_version(data)
	if version >= 8:
		if saved_location_id == &"":
			return {"invalid": true}
		var location := ContentDB.get_location(saved_location_id)
		if location == null or location.scene_path.is_empty() or not ResourceLoader.exists(location.scene_path):
			return {"invalid": true}
		var exact_scene := saved_scene == location.scene_path and ResourceLoader.exists(saved_scene)
		return {
			"scene_path": location.scene_path,
			"location_id": String(location.id),
			"spawn_id": String(location.default_spawn_id),
			"use_saved_position": exact_scene,
			"remapped": not exact_scene,
		}
	if not saved_scene.is_empty() and ResourceLoader.exists(saved_scene):
		var legacy_location := ContentDB.get_location_for_scene(saved_scene)
		return {
			"scene_path": saved_scene,
			"location_id": String(legacy_location.id) if legacy_location != null else "",
			"spawn_id": String(legacy_location.default_spawn_id) if legacy_location != null else "",
			"use_saved_position": true,
			"remapped": false,
		}
	# Direct unit/helper calls with pre-v8 empty-scene snapshots keep their old
	# no-scene-change semantics. Production load_game() migrates legacy saves to
	# v8 first, so real loads still receive a playable fallback location.
	if _snapshot_version(data) < 8 and saved_scene.is_empty() and not data.has("location_id"):
		return {"scene_path": "", "use_saved_position": true}
	var fallback := ContentDB.get_location(&"starter_town")
	if fallback != null and not fallback.scene_path.is_empty() and ResourceLoader.exists(fallback.scene_path):
		return {
			"scene_path": fallback.scene_path,
			"location_id": String(fallback.id),
			"spawn_id": String(fallback.default_spawn_id),
			"use_saved_position": false,
			"remapped": true,
		}
	return {"invalid": true}

func _apply_player_spawn(player: Node2D, spawn_id: StringName) -> bool:
	if player == null or spawn_id == &"":
		return false
	for node: Node in get_tree().get_nodes_in_group("world_spawn_point"):
		var spawn := node as WorldSpawnPoint
		if spawn != null and spawn.spawn_id == spawn_id:
			player.global_position = spawn.global_position
			return true
	return false

func _sync_snapshot_runtime_sections(data: Dictionary) -> void:
	data["game_version"] = String(ProjectSettings.get_setting("application/config/version", "unknown"))
	data["engine_version"] = String(Engine.get_version_info().get("string", "unknown"))
	# Load-time reconciliation can repair quest chains, project flags, expansion
	# entitlements, milestone qualification/rewards and newly delivered mail. Keep
	# those repairs in the candidate dictionary so promoting a backup/temp writes
	# the normalized live state, not the stale pre-repair payload.
	data["clock"] = WorldClock.to_save_data()
	data["weather"] = WeatherState.to_save_data()
	data["inventory"] = InventoryState.to_save_data()
	data["player_state"] = PlayerState.to_save_data()
	data["world"] = WorldState.to_save_data()
	data["relationships"] = RelationshipState.to_save_data()
	data["npc_memory"] = NpcMemory.to_save_data()
	data["quests"] = QuestState.to_save_data()
	data["skills"] = Skills.to_save_data()
	data["buffs"] = BuffState.to_save_data()
	data["shipping"] = ShippingState.to_save_data()
	data["fishing"] = FishingState.to_save_data()

func _read_best_snapshot(primary: String, backup: String) -> Dictionary:
	var data := _read_dictionary(primary)
	if _is_snapshot_usable(data):
		return {"data": data, "source": "primary"}
	data = _read_dictionary(backup)
	if _is_snapshot_usable(data):
		return {"data": data, "source": "backup"}
	return {}

func _read_best_loadable_snapshot(primary: String, backup: String) -> Dictionary:
	var primary_data := _read_dictionary(primary)
	var primary_usable := _is_snapshot_usable(primary_data)
	if primary_usable and _snapshot_version(primary_data) <= SAVE_VERSION:
		return {"data": primary_data, "source": "primary"}
	var newer_primary := primary_usable and _snapshot_version(primary_data) > SAVE_VERSION
	var backup_data := _read_dictionary(backup)
	if _is_snapshot_usable(backup_data) and _snapshot_version(backup_data) <= SAVE_VERSION:
		return {
			"data": backup_data,
			"source": "backup",
			"newer_primary_preserved": newer_primary,
		}
	return {}

func _read_best_slot_snapshot(primary: String, temp: String, backup: String) -> Dictionary:
	var primary_data := _read_dictionary(primary)
	if _is_snapshot_usable(primary_data):
		# A future-version primary is never displaced by a temp from this older
		# build. It remains the protected canonical save even when a compatible
		# recovery file exists alongside it.
		if _snapshot_version(primary_data) > SAVE_VERSION:
			return {"data": primary_data, "source": "primary"}
		var temp_data := _read_dictionary(temp)
		if _is_snapshot_usable(temp_data) and _snapshot_version(temp_data) <= SAVE_VERSION and _snapshot_timestamp(temp_data) > _snapshot_timestamp(primary_data):
			return {"data": temp_data, "source": "temp", "replaces_valid_primary": true}
		return {"data": primary_data, "source": "primary"}
	return _read_newest_recovery_snapshot(temp, backup, false)

func _read_best_loadable_slot_snapshot(primary: String, temp: String, backup: String) -> Dictionary:
	var primary_data := _read_dictionary(primary)
	var primary_usable := _is_snapshot_usable(primary_data)
	if primary_usable and _snapshot_version(primary_data) <= SAVE_VERSION:
		var temp_data := _read_dictionary(temp)
		if _is_snapshot_usable(temp_data) and _snapshot_version(temp_data) <= SAVE_VERSION and _snapshot_timestamp(temp_data) > _snapshot_timestamp(primary_data):
			return {"data": temp_data, "source": "temp", "replaces_valid_primary": true}
		return {"data": primary_data, "source": "primary"}
	var newer_primary := primary_usable and _snapshot_version(primary_data) > SAVE_VERSION
	var recovered := _read_newest_recovery_snapshot(temp, backup, true)
	if not recovered.is_empty():
		recovered["newer_primary_preserved"] = newer_primary
	return recovered

func _read_newest_recovery_snapshot(temp: String, backup: String, require_loadable: bool) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var backup_data := _read_dictionary(backup)
	if _is_snapshot_usable(backup_data) and (not require_loadable or _snapshot_version(backup_data) <= SAVE_VERSION):
		candidates.append({"data": backup_data, "source": "backup"})
	var temp_data := _read_dictionary(temp)
	if _is_snapshot_usable(temp_data) and (not require_loadable or _snapshot_version(temp_data) <= SAVE_VERSION):
		candidates.append({"data": temp_data, "source": "temp"})
	if candidates.is_empty():
		return {}
	# Backup wins exact timestamp ties because it is the last fully committed
	# snapshot. A temp is selected only when it is demonstrably newer or when no
	# usable backup exists.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time := _snapshot_timestamp(a["data"] as Dictionary)
		var b_time := _snapshot_timestamp(b["data"] as Dictionary)
		if a_time != b_time:
			return a_time > b_time
		return String(a.get("source", "")) == "backup"
	)
	return candidates[0].duplicate(true)

func _snapshot_timestamp(data: Dictionary) -> int:
	if data.has("saved_at_unix_msec"):
		return maxi(_safe_int(data.get("saved_at_unix_msec", 0), 0), 0)
	return maxi(int(round(_safe_float(data.get("saved_at_unix", 0.0), 0.0) * 1000.0)), 0)

func _snapshot_version(data: Dictionary) -> int:
	return maxi(_safe_int(data.get("version", 1), 1), 1)

func _safe_int(value: Variant, fallback: int = 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback

func _safe_float(value: Variant, fallback: float = 0.0) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback

func _safe_string(value: Variant, fallback := "") -> String:
	if value is String or value is StringName:
		return String(value)
	return fallback

func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

func _read_dictionary(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}

func _is_snapshot_usable(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var version := _snapshot_version(data)
	if version < 1:
		return false
	# Never validate a future-format save against this build's schema. Any
	# parseable dictionary explicitly tagged with a newer version is preserved as
	# a future primary, while loadability remains blocked by the version checks.
	if version > SAVE_VERSION:
		return true
	var clock: Variant = data.get("clock", null)
	if not clock is Dictionary or not clock.has("day") or not clock.has("minute_of_day"):
		return false
	for section: String in _required_dictionary_sections(version):
		if not data.has(section) or not data[section] is Dictionary:
			return false
	if version >= 8:
		var location_id := StringName(String(data.get("location_id", "")))
		if location_id == &"":
			return false
		var location := ContentDB.get_location(location_id)
		return location != null and not location.scene_path.is_empty() and ResourceLoader.exists(location.scene_path)
	# Pre-v8 saves had no stable Location ID. Keep a structurally complete legacy
	# snapshot usable even when its scene file was renamed/removed; migration will
	# map known paths or recover unknown/empty legacy scenes into Starter Town.
	return true

func _required_dictionary_sections(version: int) -> Array[String]:
	var sections: Array[String] = ["clock", "inventory", "world"]
	if version >= 2:
		sections.append_array(["weather", "player_state", "relationships", "quests", "skills"])
	if version >= 3:
		sections.append("npc_memory")
	if version >= 4:
		sections.append("fishing")
	if version >= 6:
		sections.append("shipping")
	if version >= 7:
		sections.append("buffs")
	return sections

func _write_dictionary(path: String, data: Dictionary) -> bool:
	if path.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return stored

func _delete_paths(paths: Array[String]) -> bool:
	var ok := true
	for path: String in paths:
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and ok
	return ok
