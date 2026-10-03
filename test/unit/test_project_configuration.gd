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
	assert_false(project.contains("addons/top_down"), "production config must not depend on the removed shooter template")
	assert_false(project.contains("addons/great_games_library"), "production config must not depend on the removed template library")
	assert_true(project.contains('Transition="*res://game/core/world/scene_transition.gd"'))

func test_legacy_shooter_addons_are_absent() -> void:
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/top_down")))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/great_games_library")))

func test_generated_output_directories_are_godot_ignored() -> void:
	assert_true(FileAccess.file_exists("res://build/.gdignore"))
	assert_true(FileAccess.file_exists("res://artifacts/.gdignore"))
	assert_true(FileAccess.file_exists("res://tools/web_smoke/.gdignore"))

func test_localization_resources_are_registered() -> void:
	var project := _read_text("res://project.godot")
	assert_true(project.contains('locale/translations=PackedStringArray("res://game/i18n/ui.zh_CN.po")'))
	assert_true(FileAccess.file_exists("res://game/i18n/ui.zh_CN.po"))

func test_input_and_autosave_services_are_registered() -> void:
	var project := _read_text("res://project.godot")
	assert_true(project.contains('InputPrompts="*res://game/core/input/input_prompt_service.gd"'))
	assert_true(project.contains('AutoSave="*res://game/core/save/auto_save_service.gd"'))

func test_game_version_is_semver_and_matches_project_and_diagnostics() -> void:
	var version := _read_text("res://.game-version").strip_edges()
	var regex := RegEx.new()
	assert_eq(regex.compile("^\\d+\\.\\d+\\.\\d+(?:-[0-9A-Za-z]+(?:\\.[0-9A-Za-z-]+)*)?$"), OK)
	assert_not_null(regex.search(version), "Game version must be semantic")
	var project := _read_text("res://project.godot")
	assert_true(project.contains('config/version="%s"' % version))
	var context := GameDiagnostics.get_runtime_context()
	assert_eq(String(context.get("game_version", "")), version)

func test_release_diagnostics_are_configured() -> void:
	var project := _read_text("res://project.godot")
	assert_true(project.contains('GameDiagnostics="*res://game/core/diagnostics/game_diagnostics.gd"'))
	assert_true(project.contains('file_logging/enable_file_logging.pc=true'))
	assert_true(project.contains('file_logging/log_path="user://logs/gamebase.log"'))
	assert_true(project.contains('file_logging/max_log_files=5'))
	assert_true(project.contains('settings/gdscript/always_track_call_stacks=true'))
	var context := GameDiagnostics.get_runtime_context()
	assert_eq(int(context.get("save_schema", 0)), GameSaveManager.SAVE_VERSION)
	assert_false(String(context.get("engine", "")).is_empty())
	assert_false(String(context.get("os", "")).is_empty())

func test_validation_pipeline_includes_long_horizon_soak() -> void:
	var validation := _read_text("res://tools/validate.ps1")
	assert_true(FileAccess.file_exists("res://test/runtime/long_horizon_soak.gd"))
	assert_true(validation.contains('test/runtime/long_horizon_soak.gd'))
	assert_true(validation.contains('[switch]$SkipSoak'))

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
		"tools/*",
		"docs/*",
		".github/*",
		"licenses/*",
		"addons/dialogue_manager/assets/*",
		"addons/dialogue_manager/components/*",
		"addons/dialogue_manager/views/*",
		"addons/dialogue_manager/plugin.gd*",
		"addons/dialogue_manager/import_plugin.gd*",
		"addons/dialogue_manager/export_plugin.gd*",
		"addons/dialogue_manager/inspector_plugin.gd*",
	]:
		assert_eq(presets.count(required_exclusion), 3, "Missing release exclusion: %s" % required_exclusion)

func test_release_packaging_verifies_contents_and_distribution_licenses() -> void:
	var exporter := _read_text("res://tools/export.ps1")
	var verifier := _read_text("res://tools/verify_export_contents.ps1")
	assert_true(exporter.contains("verify_export_contents.ps1"))
	assert_true(exporter.contains("THIRD_PARTY_NOTICES.md"))
	assert_true(exporter.contains("GODOT_COPYRIGHT.txt"))
	assert_true(exporter.contains("GODOT_VERSION.txt"))
	assert_true(exporter.contains("legal_bundle_version"))
	assert_true(exporter.contains("BUILD_INFO.json"))
	assert_true(verifier.contains("res://game/art/licensed"))
	assert_true(verifier.contains("res://addons/gut"))
	assert_true(verifier.contains("res://test"))
	assert_true(verifier.contains("res://.game-version"))
	assert_true(verifier.contains("res://BUILD_INFO.json"))
	assert_true(FileAccess.file_exists("res://THIRD_PARTY_NOTICES.md"))
	assert_true(FileAccess.file_exists("res://licenses/GAMEBASE_LICENSE.txt"))
	assert_true(FileAccess.file_exists("res://licenses/GODOT_LICENSE.txt"))
	assert_true(FileAccess.file_exists("res://licenses/GODOT_COPYRIGHT.txt"))
	assert_true(FileAccess.file_exists("res://licenses/GODOT_VERSION.txt"))
	assert_true(FileAccess.file_exists("res://licenses/DIALOGUE_MANAGER_LICENSE.txt"))

func test_release_workflow_requires_exact_game_version_tag() -> void:
	var workflow := _read_text("res://.github/workflows/release.yml")
	assert_true(workflow.contains(".game-version"))
	assert_true(workflow.contains("game_version: ${{ steps.game.outputs.version }}"))
	assert_true(workflow.contains('expected="v${{ needs.validate.outputs.game_version }}"'))
	assert_true(workflow.contains('GITHUB_REF_NAME" != "$expected'))

func test_manual_engine_overrides_use_explicit_compatibility_exports() -> void:
	var ci := _read_text("res://.github/workflows/ci.yml")
	var release := _read_text("res://.github/workflows/release.yml")
	assert_true(ci.contains("-AllowEngineDrift"))
	assert_true(release.contains("-AllowEngineDrift"))
	assert_true(ci.contains("INPUT_ENGINE_VERSION"))
	assert_true(release.contains("INPUT_ENGINE_VERSION"))

func test_latest_engine_compatibility_workflow_exists() -> void:
	var workflow := _read_text("res://.github/workflows/engine-compat.yml")
	assert_true(workflow.contains("Godot Compatibility"))
	assert_true(workflow.contains("godotengine/godot/releases/latest"))
	assert_true(workflow.contains("./tools/validate.ps1 -GodotBin godot -CleanImport"))
	assert_true(workflow.contains("./tools/export.ps1 -GodotBin godot -SkipValidation -AllowEngineDrift"))

func test_engine_baseline_is_stable_godot_four() -> void:
	var version := _read_text("res://.godot-version").strip_edges()
	var parts := version.split(".")
	assert_eq(parts.size(), 3)
	assert_eq(parts[0], "4")
	for part: String in parts:
		assert_true(part.is_valid_int(), "Engine baseline must be numeric semantic version")

func test_godot_legal_bundle_tracks_engine_baseline() -> void:
	var baseline := _read_text("res://.godot-version").strip_edges()
	var legal_version := _read_text("res://licenses/GODOT_VERSION.txt").strip_edges()
	assert_eq(legal_version, baseline)
	var updater := _read_text("res://tools/update_engine_baseline.ps1")
	assert_true(updater.contains("$Version-stable"))
	assert_true(updater.contains("LICENSE.txt"))
	assert_true(updater.contains("COPYRIGHT.txt"))
	assert_true(updater.contains("GODOT_VERSION.txt"))

func test_test_framework_matches_godot_47_line() -> void:
	var plugin := _read_text("res://addons/gut/plugin.cfg")
	var versions := _read_text("res://addons/gut/versions.json")
	assert_true(plugin.contains('version="9.7.1"'))
	assert_true(versions.contains('"9.7.1"'))
	assert_true(versions.contains('"godot_min":"4.7"'))
