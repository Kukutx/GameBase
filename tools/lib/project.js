// The parts of a game's project.godot that follow from the manifests, which
// tools/link.js writes and tools/check_layers.js keeps in step:
//   [autoload]             the core's autoloads before the modules, the
//                          autoloads of each module the game lists (a module
//                          after the modules it requires), the core's
//                          autoloads after the modules, then the game's own
//                          (gamebase/gamebase.json, the modules' entries and
//                          game.json "autoloads");
//   locale/translations    the core's catalogs, each listed module's and the
//                          game's own (game/i18n/);
//   [editor_plugins]       the plugin of every addon the game links;
//   untyped_declaration    a declaration without a type is an error
//                          ([debug] gdscript/warnings), in the game's code
//                          and the foundation's alike.
// Everything else in project.godot belongs to the game. In the game's
// .gutconfig.json it writes "dirs": the tests of the core, of each listed
// module (a module after the modules it requires) and the game's own
// (test/unit/), so every game runs the tests of the foundation it uses; and
// "pre_run_script", the core's hook that sets up every test run. In its
// export_presets.cfg it writes each preset's exclude_filter: the game's own
// filters, then the editor files of every addon it links, which its exported
// packs must not carry (tools/verify_export_contents.js).
const fs = require("node:fs");
const path = require("node:path");
const { fail, rootPath } = require("./common");
const { gamePath, readFoundation } = require("./games");

// The game's modules, each after the modules it requires, otherwise by name.
function moduleOrder(foundation, modules) {
  const order = [];
  const pending = [...modules].sort();
  while (pending.length > 0) {
    const index = pending.findIndex((module) => (foundation.modules[module].requires || []).every((required) => order.includes(required)));
    if (index < 0) fail(`gamebase.json: modules ${pending.join(", ")} cannot be ordered because their requires form a cycle; move the shared part down or invert the dependency.`);
    order.push(pending.splice(index, 1)[0]);
  }
  return order;
}

function desiredAutoloads(game, foundation = readFoundation()) {
  return [
    ...Object.entries(foundation.autoloads.before_modules),
    ...moduleOrder(foundation, game.modules).flatMap((module) => Object.entries(foundation.modules[module].autoloads || {})),
    ...Object.entries(foundation.autoloads.after_modules),
    ...Object.entries(game.manifest.autoloads || {}),
  ];
}

function catalogsIn(directory, res) {
  if (!fs.existsSync(directory)) return [];
  return fs
    .readdirSync(directory)
    .filter((name) => name.endsWith(".po"))
    .sort()
    .map((name) => `${res}/${name}`);
}

function desiredCatalogs(game) {
  return [
    ...catalogsIn(rootPath("gamebase", "core", "i18n"), "res://gamebase/core/i18n"),
    ...[...game.modules].sort().flatMap((module) => catalogsIn(rootPath("gamebase", "modules", module, "i18n"), `res://gamebase/modules/${module}/i18n`)),
    ...catalogsIn(gamePath(game, "game", "i18n"), "res://game/i18n"),
  ];
}

// The test directories of the core and of the game's modules that have one,
// then the game's own.
function desiredTestDirs(game, foundation = readFoundation()) {
  const layers = [["core"], ...moduleOrder(foundation, game.modules).map((module) => ["modules", module])];
  return [
    ...layers.filter((parts) => fs.existsSync(rootPath("gamebase", ...parts, "test"))).map((parts) => `res://gamebase/${parts.join("/")}/test/`),
    "res://test/unit/",
  ];
}

function desiredPlugins(game) {
  return game.addons.filter((addon) => fs.existsSync(rootPath("addons", addon, "plugin.cfg"))).map((addon) => `res://addons/${addon}/plugin.cfg`);
}

function packedStrings(values) {
  return `PackedStringArray(${values.map((value) => JSON.stringify(value)).join(", ")})`;
}

// project.godot as [{ name, lines }] sections; the lines before the first
// section header have the name null.
function parseSections(text) {
  const sections = [{ name: null, lines: [] }];
  for (const line of text.replace(/\r\n/g, "\n").split("\n")) {
    const header = /^\[(.+)\]$/.exec(line);
    if (header) sections.push({ name: header[1], lines: [] });
    else sections[sections.length - 1].lines.push(line);
  }
  return sections;
}

function formatSections(sections) {
  return sections
    .map((section) => {
      const body = section.lines.join("\n").replace(/^\n+|\n+$/g, "");
      if (section.name === null) return body;
      return body ? `[${section.name}]\n\n${body}` : `[${section.name}]`;
    })
    .filter((part) => part !== "")
    .join("\n\n")
    .concat("\n");
}

function sectionOf(sections, name) {
  let section = sections.find((candidate) => candidate.name === name);
  if (!section) {
    section = { name, lines: [] };
    sections.push(section);
  }
  return section;
}

// Sets `key` in the section; a new key goes where the editor would write it,
// among the section's keys in alphabetical order.
function setValue(sections, name, key, value) {
  const section = sectionOf(sections, name);
  const index = section.lines.findIndex((line) => line.startsWith(`${key}=`));
  if (index >= 0) {
    section.lines[index] = `${key}=${value}`;
    return;
  }
  let at = section.lines.findIndex((line) => /^[^=\s]+=/.test(line) && line.split("=")[0] > key);
  if (at < 0) {
    at = section.lines.length;
    while (at > 0 && section.lines[at - 1] === "") at -= 1;
  }
  section.lines.splice(at, 0, `${key}=${value}`);
}

// The project.godot text with the managed parts as the manifests say.
function syncedProject(text, game, foundation = readFoundation()) {
  const sections = parseSections(text);
  sectionOf(sections, "autoload").lines = desiredAutoloads(game, foundation).map(([name, script]) => `${name}="*${script}"`);
  setValue(sections, "internationalization", "locale/translations", packedStrings(desiredCatalogs(game)));
  setValue(sections, "editor_plugins", "enabled", packedStrings(desiredPlugins(game)));
  setValue(sections, "debug", "gdscript/warnings/untyped_declaration", "2");
  return formatSections(sections);
}

// The hook every game's test run starts with: English text and a profile of
// the run's own.
const GUT_PRE_RUN_SCRIPT = "res://gamebase/core/test/gut_pre_run.gd";

// The .gutconfig.json text with the test directories as the manifests say.
function syncedGutConfig(text, game, foundation = readFoundation()) {
  let config;
  try {
    config = JSON.parse(text);
  } catch (error) {
    fail(`${gamePath(game, ".gutconfig.json")} is not valid JSON: ${error.message}`);
  }
  return `${JSON.stringify({ ...config, dirs: desiredTestDirs(game, foundation), pre_run_script: GUT_PRE_RUN_SCRIPT }, null, 2)}\n`;
}

// The export filters that keep each addon's editor-only files out of a pack.
const ADDON_EXPORT_EXCLUDES = {
  dialogue_manager: [
    "addons/dialogue_manager/assets/*",
    "addons/dialogue_manager/components/*",
    "addons/dialogue_manager/views/*",
    "addons/dialogue_manager/plugin.gd*",
    "addons/dialogue_manager/plugin.cfg*",
    "addons/dialogue_manager/debugger_plugin.gd*",
    "addons/dialogue_manager/inspector_plugin.gd*",
    "addons/dialogue_manager/import_plugin.gd*",
    "addons/dialogue_manager/export_plugin.gd*",
    "addons/dialogue_manager/editor_translation_parser_plugin.gd*",
    "addons/dialogue_manager/*.cs*",
    "addons/dialogue_manager/example_balloon/*.cs*",
    "addons/dialogue_manager/example_balloon/ExampleBalloon.tscn",
    "addons/dialogue_manager/example_balloon/SmallExampleBalloon.tscn",
    "addons/dialogue_manager/nodes/actionable/*.cs*",
    "addons/dialogue_manager/nodes/context/*.cs*",
    "addons/dialogue_manager/nodes/dialogue_label/*.cs*",
    "addons/dialogue_manager/nodes/dialogue_label/DialogueLabel.tscn",
    "addons/dialogue_manager/nodes/marker/*.cs*",
    "addons/dialogue_manager/nodes/responses_menu/*.cs*",
  ],
};

// The filters of the game's addons, in the order the game links them.
function desiredAddonExcludes(game) {
  return game.addons.flatMap((addon) => ADDON_EXPORT_EXCLUDES[addon] || []);
}

// The export_presets.cfg text with every preset's exclude_filter as the
// manifests say: the game's own filters, then its addons'; the filters of an
// addon the game no longer links go.
function syncedExportPresets(text, game) {
  const managed = new Set(Object.values(ADDON_EXPORT_EXCLUDES).flat());
  const addons = desiredAddonExcludes(game);
  return text.replace(/^exclude_filter="([^"]*)"$/gm, (_line, filters) => {
    const own = filters.split(",").filter((filter) => filter !== "" && !managed.has(filter));
    return `exclude_filter="${[...own, ...addons].join(",")}"`;
  });
}

// The managed files of the game, as [file, function of their text].
function managedFiles(game, foundation) {
  return [
    [gamePath(game, "project.godot"), (text) => syncedProject(text, game, foundation)],
    [gamePath(game, ".gutconfig.json"), (text) => syncedGutConfig(text, game, foundation)],
    [gamePath(game, "export_presets.cfg"), (text) => syncedExportPresets(text, game)],
  ];
}

// Writes the managed parts of the game's project.godot and .gutconfig.json;
// returns whether either changed.
function syncProject(game, foundation = readFoundation()) {
  let changed = false;
  for (const [file, sync] of managedFiles(game, foundation)) {
    const text = fs.readFileSync(file, "utf8");
    const synced = sync(text);
    if (synced === text) continue;
    fs.writeFileSync(file, synced, "utf8");
    changed = true;
  }
  return changed;
}

// Whether the game's managed files hold what syncProject() would write.
function projectInSync(game, foundation = readFoundation()) {
  return managedFiles(game, foundation).every(([file, sync]) => {
    const text = fs.readFileSync(file, "utf8");
    return sync(text) === text;
  });
}

module.exports = { formatSections, parseSections, desiredAddonExcludes, desiredAutoloads, desiredCatalogs, desiredPlugins, desiredTestDirs, moduleOrder, projectInSync, syncProject, syncedExportPresets, syncedGutConfig, syncedProject };
