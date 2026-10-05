const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { fail, main, removeRecursive, resolveGodotBin, rootPath, run } = require("./lib/common");

const PROBE_PROJECT = `[application]
config/name="GameBase Export Pack Probe"

[rendering]
renderer/rendering_method="gl_compatibility"
`;

// Runs inside an empty project that mounts the exported PCK, so what it sees
// under res:// is exactly what the package contains.
const PROBE_SCRIPT = `extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("EXPORT_CONTENTS: missing PCK path")
		quit(2)
		return

	var pack_path := args[0]
	if not ProjectSettings.load_resource_pack(pack_path, true):
		push_error("EXPORT_CONTENTS: could not load PCK: %s" % pack_path)
		quit(3)
		return

	var required := [
		"res://game/ui/title_screen.tscn",
		"res://game/i18n/ui.zh_CN.po",
		"res://game/core/audio/game_audio_service.gd",
		"res://game/data/audio/music_old_mine.tres",
		"res://addons/dialogue_manager/dialogue_manager.gd",
		"res://addons/dialogue_manager/compiler/compiler.gd",
		"res://addons/dialogue_manager/settings.gd",
		"res://addons/dialogue_manager/test_scene.tscn",
		"res://addons/dialogue_manager/example_balloon/example_balloon.gd",
		"res://addons/dialogue_manager/example_balloon/example_balloon.tscn",
		"res://addons/dialogue_manager/nodes/dialogue_label/dialogue_label.tscn",
		"res://addons/dialogue_manager/nodes/responses_menu/dialogue_responses_menu.gd",
	]
	for path: String in required:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			push_error("EXPORT_CONTENTS: required runtime resource missing: %s" % path)
			quit(4)
			return

	var forbidden_files := [
		"res://.gutconfig.json",
		"res://AGENTS.md",
		"res://README.md",
		"res://LICENSE",
		"res://THIRD_PARTY_NOTICES.md",
		"res://.godot-version",
		"res://.game-version",
		"res://.gitattributes",
		"res://.gitignore",
		"res://BUILD_INFO.json",
		"res://addons/dialogue_manager/plugin.gd",
		"res://addons/dialogue_manager/plugin.cfg",
		"res://addons/dialogue_manager/debugger_plugin.gd",
		"res://addons/dialogue_manager/inspector_plugin.gd",
		"res://addons/dialogue_manager/import_plugin.gd",
		"res://addons/dialogue_manager/export_plugin.gd",
		"res://addons/dialogue_manager/editor_translation_parser_plugin.gd",
		"res://addons/dialogue_manager/DialogueManager.cs",
		"res://addons/dialogue_manager/example_balloon/ExampleBalloon.cs",
		"res://addons/dialogue_manager/example_balloon/ExampleBalloon.tscn",
		"res://addons/dialogue_manager/example_balloon/SmallExampleBalloon.tscn",
		"res://addons/dialogue_manager/nodes/dialogue_label/DialogueLabel.cs",
		"res://addons/dialogue_manager/nodes/dialogue_label/DialogueLabel.tscn",
		"res://addons/dialogue_manager/nodes/responses_menu/DialogueResponsesMenu.cs",
	]
	for path: String in forbidden_files:
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			push_error("EXPORT_CONTENTS: forbidden development file packaged: %s" % path)
			quit(5)
			return

	var forbidden_dirs := [
		"res://test",
		"res://addons/gut",
		"res://game/art/licensed",
		"res://tools",
		"res://docs",
		"res://.agents",
		"res://.github",
		"res://.devmate",
		"res://build",
		"res://artifacts",
		"res://dist",
		"res://licenses",
		"res://addons/dialogue_manager/assets",
		"res://addons/dialogue_manager/components",
		"res://addons/dialogue_manager/views",
	]
	for path: String in forbidden_dirs:
		if DirAccess.dir_exists_absolute(path):
			push_error("EXPORT_CONTENTS: forbidden development directory packaged: %s" % path)
			quit(6)
			return

	print("EXPORT_CONTENTS_OK")
	quit(0)
`;

async function verifyExportContents({ pckPath, godotBin }) {
  const godot = resolveGodotBin(godotBin);
  const resolvedPck = path.isAbsolute(pckPath) ? pckPath : rootPath(pckPath);
  if (!fs.existsSync(resolvedPck)) {
    fail(`Resource pack not found: ${pckPath}`);
  }
  const probeRoot = rootPath(".dev", `export-pack-probe-${process.pid}`);
  fs.mkdirSync(probeRoot, { recursive: true });
  fs.writeFileSync(path.join(probeRoot, "project.godot"), PROBE_PROJECT, "utf8");
  const probeScript = path.join(probeRoot, "probe.gd");
  fs.writeFileSync(probeScript, PROBE_SCRIPT, "utf8");
  try {
    const result = await run(godot, ["--headless", "--path", probeRoot, "-s", probeScript, "--", resolvedPck]);
    if (result.code !== 0) {
      fail(`Export content verification failed for '${pckPath}' with exit code ${result.code}.`);
    }
    if (!result.output.includes("EXPORT_CONTENTS_OK")) {
      fail(`Export content verification did not report success for '${pckPath}'.`);
    }
    console.log(`Export content verification passed: ${pckPath}`);
  } finally {
    removeRecursive(probeRoot);
  }
}

module.exports = { verifyExportContents };

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: { pck: { type: "string" }, "godot-bin": { type: "string" } },
    });
    if (!values.pck) {
      fail("Usage: node tools/verify_export_contents.js --pck <path> [--godot-bin <godot>]");
    }
    await verifyExportContents({ pckPath: values.pck, godotBin: values["godot-bin"] });
  });
}
