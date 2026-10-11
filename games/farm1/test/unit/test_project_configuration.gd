extends GutTest

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Expected project file: %s" % path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func test_project_config_has_no_local_development_references() -> void:
	var project := _read_text("res://project.godot")
	assert_false(project.contains("res://.dev/"), "project.godot must never reference local .dev content")
	assert_true(project.contains('Transition="*res://gamebase/core/world/scene_transition.gd"'))

func test_localization_resources_are_registered() -> void:
	var project := _read_text("res://project.godot")
	assert_true(project.contains('locale/translations=PackedStringArray("res://game/i18n/ui.zh_CN.po")'))
	assert_true(FileAccess.file_exists("res://game/i18n/ui.zh_CN.po"))

func test_input_audio_and_autosave_services_are_registered() -> void:
	var project := _read_text("res://project.godot")
	assert_true(project.contains('InputPrompts="*res://gamebase/core/input/input_prompt_service.gd"'))
	assert_true(project.contains('GameAudio="*res://gamebase/core/audio/game_audio_service.gd"'))
	assert_true(project.contains('AutoSave="*res://gamebase/core/save/auto_save_service.gd"'))
	assert_true(project.contains('SupportBundle="*res://gamebase/core/diagnostics/support_bundle_service.gd"'))

func test_game_version_is_semver_and_reaches_diagnostics() -> void:
	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	var regex := RegEx.new()
	assert_eq(regex.compile("^\\d+\\.\\d+\\.\\d+(?:-[0-9A-Za-z]+(?:\\.[0-9A-Za-z-]+)*)?$"), OK)
	assert_not_null(regex.search(version), "Game version must be semantic")
	var context := GameDiagnostics.get_runtime_context()
	assert_eq(String(context.get("game_version", "")), version)

func test_release_diagnostics_are_configured() -> void:
	var project := _read_text("res://project.godot")
	assert_true(project.contains('GameDiagnostics="*res://gamebase/core/diagnostics/game_diagnostics.gd"'))
	assert_true(bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging.pc", true)))
	assert_true(project.contains('file_logging/log_path="user://logs/farm1.log"'))
	assert_eq(int(ProjectSettings.get_setting("debug/file_logging/max_log_files", 5)), 5)
	assert_true(project.contains('settings/gdscript/always_track_call_stacks=true'))
	var context := GameDiagnostics.get_runtime_context()
	assert_eq(int(context.get("save_schema", 0)), GameSaveManager.SAVE_VERSION)
	assert_false(String(context.get("engine", "")).is_empty())
	assert_false(String(context.get("os", "")).is_empty())

func test_unit_run_does_not_inherit_the_saved_language() -> void:
	var config: Variant = JSON.parse_string(_read_text("res://.gutconfig.json"))
	assert_true(config is Dictionary)
	if config is Dictionary:
		assert_eq(String((config as Dictionary).get("pre_run_script", "")), "res://test/gut_pre_run.gd")
	assert_true(_read_text("res://test/gut_pre_run.gd").contains('TranslationServer.set_locale("en")'))
	for runtime_script: String in ["world_services_smoke.gd", "long_horizon_soak.gd"]:
		assert_true(_read_text("res://test/runtime/%s" % runtime_script).contains('TranslationServer.set_locale("en")'), runtime_script)

func test_project_uses_web_compatible_renderer() -> void:
	var project := _read_text("res://project.godot")
	assert_true(project.contains('config/features=PackedStringArray("4.7", "GL Compatibility")'))
	assert_true(project.contains('renderer/rendering_method="gl_compatibility"'))

func test_export_presets_cover_supported_release_targets() -> void:
	var presets := _read_text("res://export_presets.cfg")
	assert_true(presets.contains('name="Windows Desktop"'))
	assert_true(presets.contains('name="Linux"'))
	assert_true(presets.contains('name="Web"'))
	for required_exclusion: String in [
		"test/*",
		"addons/gut/*",
		"game/art/licensed/*",
		".gutconfig.json",
		"game.json",
		"addons/dialogue_manager/assets/*",
		"addons/dialogue_manager/components/*",
		"addons/dialogue_manager/views/*",
		"addons/dialogue_manager/plugin.gd*",
		"addons/dialogue_manager/debugger_plugin.gd*",
		"addons/dialogue_manager/import_plugin.gd*",
		"addons/dialogue_manager/export_plugin.gd*",
		"addons/dialogue_manager/inspector_plugin.gd*",
		"addons/dialogue_manager/*.cs*",
		"addons/dialogue_manager/example_balloon/*.cs*",
		"addons/dialogue_manager/example_balloon/ExampleBalloon.tscn",
		"addons/dialogue_manager/example_balloon/SmallExampleBalloon.tscn",
		"addons/dialogue_manager/nodes/dialogue_label/DialogueLabel.tscn",
		"addons/dialogue_manager/nodes/responses_menu/*.cs*",
	]:
		assert_eq(presets.count(required_exclusion), 3, "Missing release exclusion: %s" % required_exclusion)
