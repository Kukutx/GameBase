const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { fail, main, removeRecursive, resolveGodotBin, run, tempFile } = require("./lib/common");
const { projectSetting, resolveGame } = require("./lib/games");

const PROBE_PROJECT = `[application]
config/name="GameBase Export Pack Probe"

[rendering]
renderer/rendering_method="gl_compatibility"
`;

// Runtime files an addon loads by path, which a pack must carry when the game
// links the addon, and its editor-only files, which a pack must not carry.
const ADDON_RUNTIME = {
  dialogue_manager: [
    "res://addons/dialogue_manager/compiler/compiler.gd",
    "res://addons/dialogue_manager/settings.gd",
    "res://addons/dialogue_manager/test_scene.tscn",
    "res://addons/dialogue_manager/example_balloon/example_balloon.gd",
    "res://addons/dialogue_manager/example_balloon/example_balloon.tscn",
    "res://addons/dialogue_manager/nodes/dialogue_label/dialogue_label.tscn",
    "res://addons/dialogue_manager/nodes/responses_menu/dialogue_responses_menu.gd",
  ],
};
const ADDON_EDITOR_FILES = {
  dialogue_manager: [
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
  ],
};
const ADDON_EDITOR_DIRS = {
  dialogue_manager: ["res://addons/dialogue_manager/assets", "res://addons/dialogue_manager/components", "res://addons/dialogue_manager/views"],
};

// What a game's pack must and must not contain. Required: the main scene, the
// game definition, every autoload script, every registered translation and the
// runtime files of its addons. Forbidden: tests (the game's and those of the
// foundation layers it links), the test addon, the local
// licensed source art, the game manifest, build metadata and addon editor files.
function expectations(game) {
  const strings = (raw) => [...String(raw || "").matchAll(/"(res:\/\/[^"]+)"/g)].map((match) => match[1]);
  const required = new Set([
    ...strings(projectSetting(game, "application", "run/main_scene")),
    ...strings(projectSetting(game, "gamebase", "game_definition")),
    ...strings(projectSetting(game, "internationalization", "locale/translations")),
  ]);
  const project = fs.readFileSync(path.join(game.root, "project.godot"), "utf8");
  for (const match of project.matchAll(/^\w+="\*(res:\/\/[^"]+)"$/gm)) required.add(match[1]);
  // The font GameSettings loads by path as every game's fallback font.
  required.add("res://gamebase/core/ui/fonts/noto_sans_sc.woff2");
  const files = ["res://.gutconfig.json", "res://game.json", "res://BUILD_INFO.json"];
  const dirs = [
    "res://test",
    "res://gamebase/core/test",
    ...game.modules.map((module) => `res://gamebase/modules/${module}/test`),
    "res://addons/gut",
    "res://game/art/licensed",
  ];
  for (const addon of game.addons) {
    for (const file of ADDON_RUNTIME[addon] || []) required.add(file);
    files.push(...(ADDON_EDITOR_FILES[addon] || []));
    dirs.push(...(ADDON_EDITOR_DIRS[addon] || []));
  }
  return { required: [...required].sort(), forbidden_files: files, forbidden_dirs: dirs };
}

// Runs inside an empty project that mounts the exported PCK, so what it sees
// under res:// is exactly what the package contains.
const PROBE_SCRIPT = `extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("EXPORT_CONTENTS: expected the PCK path and the expectations file")
		quit(2)
		return

	var pack_path := args[0]
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not expected is Dictionary:
		push_error("EXPORT_CONTENTS: could not read the expectations file")
		quit(2)
		return
	if not ProjectSettings.load_resource_pack(pack_path, true):
		push_error("EXPORT_CONTENTS: could not load PCK: %s" % pack_path)
		quit(3)
		return

	for path: String in expected["required"]:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			push_error("EXPORT_CONTENTS: required runtime resource missing: %s" % path)
			quit(4)
			return
	for path: String in expected["forbidden_files"]:
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			push_error("EXPORT_CONTENTS: forbidden development file packaged: %s" % path)
			quit(5)
			return
	for path: String in expected["forbidden_dirs"]:
		if DirAccess.dir_exists_absolute(path):
			push_error("EXPORT_CONTENTS: forbidden development directory packaged: %s" % path)
			quit(6)
			return

	print("EXPORT_CONTENTS_OK")
	quit(0)
`;

async function verifyExportContents({ game, pckPath, godotBin }) {
  const godot = resolveGodotBin(godotBin);
  const resolvedPck = path.resolve(pckPath);
  if (!fs.existsSync(resolvedPck)) {
    fail(`Resource pack not found: ${pckPath}`);
  }
  const probeRoot = tempFile("gamebase-export-pack-probe");
  fs.mkdirSync(probeRoot, { recursive: true });
  fs.writeFileSync(path.join(probeRoot, "project.godot"), PROBE_PROJECT, "utf8");
  const probeScript = path.join(probeRoot, "probe.gd");
  fs.writeFileSync(probeScript, PROBE_SCRIPT, "utf8");
  const expectationsFile = path.join(probeRoot, "expected.json");
  fs.writeFileSync(expectationsFile, JSON.stringify(expectations(game)), "utf8");
  try {
    const result = await run(godot, ["--headless", "--path", probeRoot, "-s", probeScript, "--", resolvedPck, expectationsFile]);
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

module.exports = { verifyExportContents, expectations };

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: { game: { type: "string" }, pck: { type: "string" }, "godot-bin": { type: "string" } },
    });
    if (!values.pck) {
      fail("Usage: node tools/verify_export_contents.js [--game <id>] --pck <path> [--godot-bin <godot>]");
    }
    await verifyExportContents({ game: resolveGame(values.game), pckPath: values.pck, godotBin: values["godot-bin"] });
  });
}
