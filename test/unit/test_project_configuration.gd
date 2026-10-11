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
	assert_true(project.contains('Transition="*res://gamebase/core/world/scene_transition.gd"'))

func test_legacy_shooter_addons_are_absent() -> void:
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/top_down")))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/great_games_library")))

func test_generated_output_directories_are_godot_ignored() -> void:
	assert_true(FileAccess.file_exists("res://build/.gdignore"))
	assert_true(FileAccess.file_exists("res://artifacts/.gdignore"))
	assert_true(FileAccess.file_exists("res://dist/.gdignore"))
	assert_true(FileAccess.file_exists("res://tools/web_smoke/.gdignore"))

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
	assert_true(project.contains('GameDiagnostics="*res://gamebase/core/diagnostics/game_diagnostics.gd"'))
	assert_true(bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging.pc", true)))
	assert_true(project.contains('file_logging/log_path="user://logs/gamebase.log"'))
	assert_eq(int(ProjectSettings.get_setting("debug/file_logging/max_log_files", 5)), 5)
	assert_true(project.contains('settings/gdscript/always_track_call_stacks=true'))
	var context := GameDiagnostics.get_runtime_context()
	assert_eq(int(context.get("save_schema", 0)), GameSaveManager.SAVE_VERSION)
	assert_false(String(context.get("engine", "")).is_empty())
	assert_false(String(context.get("os", "")).is_empty())

func test_validation_pipeline_includes_long_horizon_soak() -> void:
	var validation := _read_text("res://tools/validate.js")
	assert_true(FileAccess.file_exists("res://test/runtime/long_horizon_soak.gd"))
	assert_true(validation.contains('test/runtime/long_horizon_soak.gd'))
	assert_true(validation.contains('"skip-soak"'))
	assert_true(validation.contains('"--import"'))
	assert_false(validation.contains("Post-import settle / parse"))

func test_validation_pipeline_checks_agent_rules_and_tools() -> void:
	var validation := _read_text("res://tools/validate.js")
	assert_true(FileAccess.file_exists("res://tools/validate_rules.js"))
	assert_true(FileAccess.file_exists("res://tools/validate_rules.test.js"))
	assert_true(validation.contains('require("./validate_rules")'))
	assert_true(validation.contains('runRulesCheck(["--strict"])'))
	assert_true(validation.contains('"tools/*.test.js"'))

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
		"tools/*",
		"docs/*",
		".agents/*",
		"dist/*",
		".github/*",
		"licenses/*",
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

func test_release_packaging_verifies_contents_and_distribution_licenses() -> void:
	var exporter := _read_text("res://tools/export.js")
	var verifier := _read_text("res://tools/verify_export_contents.js")
	assert_true(exporter.contains('require("./verify_export_contents")'))
	assert_true(exporter.contains("THIRD_PARTY_NOTICES.md"))
	assert_true(exporter.contains("GODOT_COPYRIGHT.txt"))
	assert_true(exporter.contains("GODOT_VERSION.txt"))
	assert_true(exporter.contains("legal_bundle_version"))
	assert_true(exporter.contains("BUILD_INFO.json"))
	assert_true(FileAccess.file_exists("res://tools/generate_release_manifest.js"))
	assert_true(verifier.contains("res://game/art/licensed"))
	assert_true(verifier.contains("res://addons/gut"))
	assert_true(verifier.contains("res://test"))
	assert_true(verifier.contains("res://dist"))
	assert_true(verifier.contains("res://.game-version"))
	assert_true(verifier.contains("res://BUILD_INFO.json"))
	assert_true(FileAccess.file_exists("res://THIRD_PARTY_NOTICES.md"))
	assert_true(FileAccess.file_exists("res://licenses/GAMEBASE_LICENSE.txt"))
	assert_true(FileAccess.file_exists("res://licenses/GODOT_LICENSE.txt"))
	assert_true(FileAccess.file_exists("res://licenses/GODOT_COPYRIGHT.txt"))
	assert_true(FileAccess.file_exists("res://licenses/GODOT_VERSION.txt"))
	assert_true(FileAccess.file_exists("res://licenses/DIALOGUE_MANAGER_LICENSE.txt"))

func test_release_archives_use_deterministic_repository_packager() -> void:
	var workflow := _read_text("res://.github/workflows/release.yml")
	var validation := _read_text("res://tools/validate.js")
	var packager := _read_text("res://tools/package_release.js")
	var archive := _read_text("res://tools/lib/archive.js")
	assert_true(workflow.contains("tools/package_release.js"))
	assert_false(workflow.contains("zip -r"))
	assert_false(workflow.contains("tar -czf"))
	assert_true(workflow.contains("node-version: 24"))
	assert_false(workflow.contains("setup-python"))
	assert_true(validation.contains('require("./package_release")'))
	assert_true(validation.contains("runSelfTest()"))
	assert_true(packager.contains("SOURCE_DATE_EPOCH"))
	assert_true(packager.contains("DETERMINISTIC_PACKAGING_OK"))
	assert_true(packager.contains("canonicalMode"))
	assert_true(archive.contains("gzipDeterministic"))
	assert_true(archive.contains('tarField(header, 265, 32, "root")'))
	var readiness := _read_text("res://tools/release_readiness.js")
	assert_true(readiness.contains("packageTarget(target"))
	assert_true(readiness.contains('"generate_release_manifest.js"), "--dist", "dist"'))
	assert_true(readiness.contains('"--untracked-files=all"'))
	assert_true(readiness.contains("clean Git working tree"))

func test_release_workflow_validates_packaged_identity_and_manifest() -> void:
	var workflow := _read_text("res://.github/workflows/release.yml")
	var generator := _read_text("res://tools/generate_release_manifest.js")
	assert_true(workflow.contains("tools/generate_release_manifest.js"))
	assert_true(workflow.contains("RELEASE_MANIFEST.json") or generator.contains("RELEASE_MANIFEST.json"))
	assert_true(generator.contains("SHA256SUMS.txt"))
	assert_true(generator.contains("BUILD_INFO.json"))
	assert_true(generator.contains("THIRD_PARTY_NOTICES.md"))
	assert_true(generator.contains("licenses/GODOT_VERSION.txt"))
	assert_true(generator.contains("dirty"))
	assert_true(generator.contains("dialogue_manager"))
	assert_true(generator.contains("gut"))

func test_release_workflow_requires_exact_game_version_tag() -> void:
	var workflow := _read_text("res://.github/workflows/release.yml")
	assert_true(workflow.contains(".game-version"))
	assert_true(workflow.contains("game_version: ${{ steps.game.outputs.version }}"))
	assert_true(workflow.contains('verify-tag --expected "${{ needs.validate.outputs.game_version }}"'))
	assert_true(_read_text("res://tools/ci.js").contains("process.env.GITHUB_REF_NAME !== `v${version}`"))
	assert_true(workflow.contains("github.event_name != 'workflow_dispatch'"))
	assert_true(workflow.contains("inputs.engine_version == ''"))

func test_manual_engine_overrides_use_explicit_compatibility_exports() -> void:
	var ci := _read_text("res://.github/workflows/ci.yml")
	var release := _read_text("res://.github/workflows/release.yml")
	assert_true(ci.contains("--allow-engine-drift"))
	assert_true(release.contains("--allow-engine-drift"))
	assert_true(ci.contains("INPUT_ENGINE_VERSION"))
	assert_true(release.contains("INPUT_ENGINE_VERSION"))

func test_addon_freshness_workflow_exists_and_is_advisory() -> void:
	var workflow := _read_text("res://.github/workflows/addon-freshness.yml")
	var checker := _read_text("res://tools/check_addon_updates.js")
	var ci_tool := _read_text("res://tools/ci.js")
	assert_true(workflow.contains("Addon Freshness"))
	assert_true(workflow.contains("schedule:"))
	assert_true(workflow.contains("issues: write"))
	assert_true(workflow.contains("tools/check_addon_updates.js"))
	assert_true(workflow.contains("tools/ci.js addon-issue"))
	assert_true(ci_tool.contains('"issue", "create"'))
	assert_true(ci_tool.contains('"close", String(existing.number)'))
	assert_false(workflow.contains("git commit"))
	assert_false(workflow.contains("git push"))
	assert_true(checker.contains("nathanhoad/godot_dialogue_manager.git"))
	assert_true(checker.contains("bitwes/Gut.git"))
	assert_true(checker.contains('"dialogue_manager"'))
	assert_true(checker.contains('"gut"'))
	assert_true(checker.contains('"plugin.cfg"'))

func test_latest_engine_compatibility_workflow_exists() -> void:
	var workflow := _read_text("res://.github/workflows/engine-compat.yml")
	assert_true(workflow.contains("Godot Compatibility"))
	assert_true(workflow.contains("node tools/ci.js engine-version --latest"))
	assert_true(_read_text("res://tools/ci.js").contains("godotengine/godot/releases/latest"))
	assert_true(workflow.contains("node tools/validate.js --godot-bin godot --clean-import"))
	assert_true(workflow.contains("node tools/export.js --godot-bin godot --skip-validation --allow-engine-drift"))

func test_repository_tooling_is_node_only() -> void:
	var pending: Array[String] = ["res://tools"]
	var offenders: Array[String] = []
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		for name: String in DirAccess.get_directories_at(directory):
			if name != "node_modules":
				pending.append(directory.path_join(name))
		for name: String in DirAccess.get_files_at(directory):
			if name.get_extension().to_lower() in ["py", "ps1", "sh", "bat", "cmd", "rb", "pl"]:
				offenders.append(directory.path_join(name))
	assert_eq(offenders.size(), 0, "tools/ holds Node scripts only: %s" % ", ".join(offenders))
	for workflow_name: String in ["ci.yml", "release.yml", "engine-compat.yml", "addon-freshness.yml"]:
		var workflow := _read_text("res://.github/workflows/%s" % workflow_name)
		assert_false(workflow.contains("shell: pwsh"), "%s must not use PowerShell" % workflow_name)
		assert_false(workflow.contains("setup-python"), "%s must not set up Python" % workflow_name)

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
	var updater := _read_text("res://tools/update_engine_baseline.js")
	assert_true(updater.contains("`${version}-stable`"))
	assert_true(updater.contains("LICENSE.txt"))
	assert_true(updater.contains("COPYRIGHT.txt"))
	assert_true(updater.contains("GODOT_VERSION.txt"))

func test_addon_versions_match_godot_47_line() -> void:
	var gut_plugin := _read_text("res://addons/gut/plugin.cfg")
	var gut_versions := _read_text("res://addons/gut/versions.json")
	assert_true(gut_plugin.contains('version="9.7.1"'))
	assert_true(gut_versions.contains('"9.7.1"'))
	assert_true(gut_versions.contains('"godot_min":"4.7"'))
	var dialogue_plugin := _read_text("res://addons/dialogue_manager/plugin.cfg")
	assert_true(dialogue_plugin.contains('version="4.1.0"'))
	var dialogue_resource := _read_text("res://addons/dialogue_manager/dialogue_resource.gd")
	assert_true(dialogue_resource.contains("var cues: Dictionary"))
	assert_true(dialogue_resource.contains("var first_cue: String"))
