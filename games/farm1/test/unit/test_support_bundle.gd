extends GutTest

const TEST_ZIP := "user://support_bundle_test.zip"
const TEST_LOG_DIR := "user://support_bundle_test_logs"
# The bundle takes the logs named after the project log file (user://logs/farm1.log).
const TEST_LOG := "user://support_bundle_test_logs/farm1-test.log"

func before_each() -> void:
	_cleanup()

func after_each() -> void:
	_cleanup()

func test_support_summary_uses_privacy_safe_whitelist() -> void:
	var service := SupportBundleService.new()
	add_child_autofree(service)
	var summary := service.build_summary()
	var privacy: Dictionary = summary.get("privacy", {})
	assert_false(bool(privacy.get("raw_saves_included", true)))
	assert_false(bool(privacy.get("raw_settings_file_included", true)))
	assert_true(bool(privacy.get("absolute_paths_redacted", false)))
	assert_false(bool(privacy.get("licensed_source_art_included", true)))
	assert_eq((summary.get("save_slots", []) as Array).size(), GameSaveManager.SLOT_COUNT)
	var encoded := JSON.stringify(summary)
	assert_false(encoded.contains("settings.cfg"))
	assert_false(encoded.contains("savegame.json"))
	assert_false(encoded.contains(ProjectSettings.globalize_path("user://")))

func test_support_bundle_contains_only_sanitized_summary_notes_and_logs() -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_LOG_DIR)), OK)
	var fake_path := ProjectSettings.globalize_path("user://")
	var file := FileAccess.open(TEST_LOG, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("ERROR: fake path %ssecret.txt\nGAMEBASE_DIAGNOSTIC test\n" % fake_path)
	file.close()

	var service := SupportBundleService.new()
	service.logs_directory = TEST_LOG_DIR
	add_child_autofree(service)
	var bundle_path := service.create_bundle(TEST_ZIP)
	assert_eq(bundle_path, TEST_ZIP)
	assert_true(FileAccess.file_exists(TEST_ZIP))

	var reader := ZIPReader.new()
	assert_eq(reader.open(TEST_ZIP), OK)
	var files := reader.get_files()
	assert_has(files, "support_summary.json")
	assert_has(files, "README.txt")
	assert_has(files, "logs/farm1-test.log")
	for path: String in files:
		assert_false(path.contains("savegame"), "Raw save must never be bundled: %s" % path)
		assert_false(path.contains("settings.cfg"), "Raw settings must never be bundled: %s" % path)
		assert_false(path.contains("licensed"), "Licensed art must never be bundled: %s" % path)

	var summary_text := reader.read_file("support_summary.json").get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(summary_text)
	assert_true(parsed is Dictionary)
	if parsed is Dictionary:
		var privacy: Dictionary = (parsed as Dictionary).get("privacy", {})
		assert_false(bool(privacy.get("raw_saves_included", true)))
		assert_true(bool(privacy.get("absolute_paths_redacted", false)))

	var log_text := reader.read_file("logs/farm1-test.log").get_string_from_utf8()
	assert_false(log_text.contains(fake_path))
	assert_true(log_text.contains("<USER_DATA>"))
	assert_true(log_text.contains("GAMEBASE_DIAGNOSTIC test"))
	reader.close()

func test_truncated_log_tail_starts_at_a_full_line() -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_LOG_DIR)), OK)
	var line := "日志日志日志\n"
	var line_bytes := line.to_utf8_buffer().size()
	var lines_in_cap := int(SupportBundleService.MAX_LOG_BYTES / line_bytes)
	var file := FileAccess.open(TEST_LOG, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(line.repeat(lines_in_cap + 2))
	file.close()
	var written := FileAccess.open(TEST_LOG, FileAccess.READ)
	written.seek(written.get_length() - SupportBundleService.MAX_LOG_BYTES)
	var first_kept_byte := written.get_8()
	written.close()
	assert_eq(first_kept_byte & 0xC0, 0x80, "The cut has to land inside a multi-byte character for this test to mean anything")

	var service := SupportBundleService.new()
	add_child_autofree(service)
	var tail := (service.call("_read_log_tail", TEST_LOG) as PackedByteArray).get_string_from_utf8()
	assert_true(tail.begins_with(line), tail.left(40))
	assert_false(tail.contains(char(0xFFFD)))
	assert_lte(tail.to_utf8_buffer().size(), SupportBundleService.MAX_LOG_BYTES)

func _cleanup() -> void:
	for path in [TEST_ZIP, TEST_LOG]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var log_dir := ProjectSettings.globalize_path(TEST_LOG_DIR)
	if DirAccess.dir_exists_absolute(log_dir):
		DirAccess.remove_absolute(log_dir)
