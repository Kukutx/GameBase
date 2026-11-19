extends GutTest

## The diagnostics name the very build a report comes from
## (`GameDiagnosticsService`): an export knows its commit, and the version a
## player sees carries it.

const VERSION_SETTING := "application/config/version"

func after_each() -> void:
	ProjectSettings.set_setting(GameDiagnosticsService.BUILD_SETTING, null)

func test_a_run_from_the_project_has_no_build() -> void:
	var version := String(ProjectSettings.get_setting(VERSION_SETTING, "unknown"))
	assert_eq(GameDiagnosticsService.get_build(), "")
	assert_eq(GameDiagnosticsService.version_text(), "v%s" % version)

func test_an_export_shows_its_build_beside_its_version() -> void:
	var version := String(ProjectSettings.get_setting(VERSION_SETTING, "unknown"))
	ProjectSettings.set_setting(GameDiagnosticsService.BUILD_SETTING, "4c812db-dirty")
	assert_eq(GameDiagnosticsService.version_text(), "v%s (4c812db-dirty)" % version)
	var context := GameDiagnostics.get_runtime_context()
	assert_eq(context.get("build"), "4c812db-dirty")
	assert_eq(context.get("os_version"), OS.get_version(), "the system's version, as a phone's matters")
