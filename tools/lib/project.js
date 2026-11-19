// The parts of a game's project.godot that follow from the manifests, which
// tools/link.js writes and tools/check_layers.js keeps in step:
//   [autoload]             the core's autoloads before the modules, the
//                          autoloads of each module the game lists (a module
//                          after the modules it requires), the core's
//                          autoloads after the modules, then the game's own
//                          (tiamat/tiamat.json, the modules' entries and
//                          game.json "autoloads");
//   locale/translations    the core's catalogs, each listed module's and the
//                          game's own (game/i18n/);
//   [editor_plugins]       the plugin of every addon the game links;
//   untyped_declaration    a declaration without a type is an error
//                          ([debug] gdscript/warnings), in the game's code
//                          and the foundation's alike;
//   import_etc2_astc       textures also import for phones and Apple
//                          silicon ([rendering] textures/vram_compression),
//                          which the Android and macOS exports need;
//   quit_on_go_back        Android's back button does not quit
//                          ([application] config/quit_on_go_back): the
//                          core's TouchControls go back with it;
//   mobile_file_logging    a phone writes its log as a computer does
//                          ([debug] file_logging/enable_file_logging.mobile),
//                          so a support report copied there holds it;
//   name_localized         the game's name in each language its catalogs
//                          translate config/name to ([application]
//                          config/name_localized) in its own catalogs
//                          (game/i18n/), which names the window and a
//                          phone's app; a language the game names by hand
//                          and no catalog translates stays;
//   orientation            a phone held either way up shows the game the
//                          right way up ([display] window/handheld/
//                          orientation): sensor landscape for a view wider
//                          than tall, sensor portrait otherwise; a game that
//                          names an orientation keeps it.
// Everything else in project.godot belongs to the game. In the game's
// .gutconfig.json it writes "dirs": the tests of the core, of each listed
// module (a module after the modules it requires) and the game's own
// (test/unit/), so every game runs the tests of the foundation it uses; and
// "pre_run_script", the core's hook that sets up every test run. In its
// export_presets.cfg it adds the preset of every export target the game
// lacks, from the new-game template (tools/lib/targets.js), and writes what
// follows from the game: where each preset exports to, its application id,
// Android's version code from the game's version, its launcher icon's layers
// (tools/render_android_icon.js) and empty keystore fields (signing keys come
// from the environment, never from the repository); and
// each preset's exclude_filter: the game's own filters, then the editor files
// of every addon it links, which its exported packs must not carry
// (tools/verify_export_contents.js).
const fs = require("node:fs");
const path = require("node:path");
const { fail, rootPath } = require("./common");
const { gamePath, gameVersion, readFoundation } = require("./games");
const { PRESET_NAMES, androidVersionCode, applicationId, targetOfPreset, targetsFor } = require("./targets");
const { androidIconPaths, hasAndroidIcon } = require("./android_icon");

// The game's modules, each after the modules it requires, otherwise by name.
function moduleOrder(foundation, modules) {
  const order = [];
  const pending = [...modules].sort();
  while (pending.length > 0) {
    const index = pending.findIndex((module) => (foundation.modules[module].requires || []).every((required) => order.includes(required)));
    if (index < 0) fail(`tiamat.json: modules ${pending.join(", ")} cannot be ordered because their requires form a cycle; move the shared part down or invert the dependency.`);
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
    ...catalogsIn(rootPath("tiamat", "core", "i18n"), "res://tiamat/core/i18n"),
    ...[...game.modules].sort().flatMap((module) => catalogsIn(rootPath("tiamat", "modules", module, "i18n"), `res://tiamat/modules/${module}/i18n`)),
    ...catalogsIn(gamePath(game, "game", "i18n"), "res://game/i18n"),
  ];
}

// The test directories of the core and of the game's modules that have one,
// then the game's own.
function desiredTestDirs(game, foundation = readFoundation()) {
  const layers = [["core"], ...moduleOrder(foundation, game.modules).map((module) => ["modules", module])];
  return [
    ...layers.filter((parts) => fs.existsSync(rootPath("tiamat", ...parts, "test"))).map((parts) => `res://tiamat/${parts.join("/")}/test/`),
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

// The lines `key` spans in the section from `index`: one, or a value the
// editor wrote over several lines (a dictionary, "{" to "}").
function valueLength(lines, index) {
  if (!lines[index].endsWith("{")) return 1;
  const end = lines.indexOf("}", index + 1);
  return end < 0 ? 1 : end - index + 1;
}

// The value of `key` in the section, as written (every line of it), or null.
function getValue(sections, name, key) {
  const section = sections.find((candidate) => candidate.name === name);
  if (!section) return null;
  const index = section.lines.findIndex((line) => line.startsWith(`${key}=`));
  if (index < 0) return null;
  return section.lines.slice(index, index + valueLength(section.lines, index)).join("\n").slice(key.length + 1);
}

// Sets `key` in the section; a new key goes where the editor would write it,
// among the section's keys in alphabetical order.
function setValue(sections, name, key, value) {
  const section = sectionOf(sections, name);
  const index = section.lines.findIndex((line) => line.startsWith(`${key}=`));
  if (index >= 0) {
    section.lines.splice(index, valueLength(section.lines, index), `${key}=${value}`);
    return;
  }
  let at = section.lines.findIndex((line) => /^[^=\s]+=/.test(line) && line.split("=")[0] > key);
  if (at < 0) {
    at = section.lines.length;
    while (at > 0 && section.lines[at - 1] === "") at -= 1;
  }
  section.lines.splice(at, 0, `${key}=${value}`);
}

// The translation of `msgid` in the gettext catalog `text`, or "" (a catalog
// leaves an entry it does not translate empty).
function poTranslation(text, msgid) {
  const entries = text.replace(/\r\n/g, "\n").split(/\n\n+/);
  for (const entry of entries) {
    const id = /^msgid ("(?:[^"\\]|\\.)*")$/m.exec(entry);
    const str = /^msgstr ("(?:[^"\\]|\\.)*")$/m.exec(entry);
    if (!id || !str) continue;
    try {
      if (JSON.parse(id[1]) === msgid) return JSON.parse(str[1]);
    } catch {
      // An entry JSON cannot read is no name.
    }
  }
  return "";
}

// The game's name `name` in each language the game's own catalogs translate
// it to (game/i18n/, by each catalog's Language header); the foundation's
// catalogs translate menu words, not a game's name.
function localizedNames(game, name) {
  const names = {};
  for (const catalog of catalogsIn(gamePath(game, "game", "i18n"), "res://game/i18n")) {
    const file = gamePath(game, ...catalog.slice("res://".length).split("/"));
    const text = fs.readFileSync(file, "utf8");
    const locale = /^"Language: ([^"\\]+)\\n"$/m.exec(text);
    const translated = poTranslation(text, name);
    if (locale && translated && translated !== name) names[locale[1]] = translated;
  }
  return names;
}

// config/name_localized as the editor writes it, from { locale: name }.
function localizedNamesValue(names) {
  const entries = Object.keys(names)
    .sort()
    .map((locale) => `${JSON.stringify(locale)}: ${JSON.stringify(names[locale])}`);
  return `{\n${entries.join(",\n")}\n}`;
}

// The { locale: name } a config/name_localized value holds.
function parseLocalizedNames(value) {
  const names = {};
  if (!value) return names;
  for (const match of value.matchAll(/("(?:[^"\\]|\\.)*")\s*:\s*("(?:[^"\\]|\\.)*")/g)) {
    try {
      names[JSON.parse(match[1])] = JSON.parse(match[2]);
    } catch {
      // Left out.
    }
  }
  return names;
}

// Godot's DisplayServer.ScreenOrientation for a phone, from the shape of the
// game's view (Godot's default view, 1152x648, when the game sets none).
const SCREEN_SENSOR_LANDSCAPE = 4;
const SCREEN_SENSOR_PORTRAIT = 5;

function handheldOrientation(sections) {
  const width = Number(getValue(sections, "display", "window/size/viewport_width") ?? 1152);
  const height = Number(getValue(sections, "display", "window/size/viewport_height") ?? 648);
  return width >= height ? SCREEN_SENSOR_LANDSCAPE : SCREEN_SENSOR_PORTRAIT;
}

// The project.godot text with the managed parts as the manifests say.
function syncedProject(text, game, foundation = readFoundation()) {
  const sections = parseSections(text);
  sectionOf(sections, "autoload").lines = desiredAutoloads(game, foundation).map(([name, script]) => `${name}="*${script}"`);
  setValue(sections, "internationalization", "locale/translations", packedStrings(desiredCatalogs(game)));
  setValue(sections, "editor_plugins", "enabled", packedStrings(desiredPlugins(game)));
  setValue(sections, "debug", "gdscript/warnings/untyped_declaration", "2");
  setValue(sections, "rendering", "textures/vram_compression/import_etc2_astc", "true");
  setValue(sections, "application", "config/quit_on_go_back", "false");
  setValue(sections, "debug", "file_logging/enable_file_logging.mobile", "true");
  const name = getValue(sections, "application", "config/name");
  if (name) {
    let gameName = "";
    try {
      gameName = JSON.parse(name);
    } catch {
      // A name JSON cannot read is translated by hand.
    }
    const names = { ...parseLocalizedNames(getValue(sections, "application", "config/name_localized")), ...(gameName ? localizedNames(game, gameName) : {}) };
    if (Object.keys(names).length > 0) setValue(sections, "application", "config/name_localized", localizedNamesValue(names));
  }
  // The template leaves it to the game, whose view may not keep the template's shape.
  if (!game.template && getValue(sections, "display", "window/handheld/orientation") === null) {
    setValue(sections, "display", "window/handheld/orientation", String(handheldOrientation(sections)));
  }
  return formatSections(sections);
}

// The hook every game's test run starts with: English text and a profile of
// the run's own.
const GUT_PRE_RUN_SCRIPT = "res://tiamat/core/test/gut_pre_run.gd";

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

// The presets of an export_presets.cfg as sections: [{ name, header, options }].
function presetsOf(sections) {
  return sections
    .filter((section) => /^preset\.\d+$/.test(section.name))
    .map((header) => {
      const line = header.lines.find((candidate) => candidate.startsWith("name="));
      return {
        name: line ? JSON.parse(line.slice("name=".length)) : null,
        header,
        options: sections.find((section) => section.name === `${header.name}.options`) || null,
      };
    });
}

// The presets of the new-game template, from which a game gets a preset of
// a target it lacks.
function templatePresets() {
  return presetsOf(parseSections(fs.readFileSync(rootPath("tiamat", "templates", "new_game", "export_presets.cfg"), "utf8")));
}

// The Android permissions of the core and the game's modules, each a
// permissions/<name> option of its Android preset: on when the core needs it
// (vibrate, which shakes the phone) or a module of the game does (the npc_ai
// module's language model reaches the internet), off when neither does.
function androidPermissions(game, foundation) {
  const declared = (module) => foundation.modules[module].android_permissions || [];
  const wanted = new Set([...foundation.androidPermissions, ...game.modules.flatMap(declared)]);
  const managed = [...new Set([...foundation.androidPermissions, ...Object.keys(foundation.modules).flatMap(declared)])].sort();
  return Object.fromEntries(managed.map((permission) => [`permissions/${permission}`, String(wanted.has(permission))]));
}

// What the game decides for none of its presets.
function derivedPresetValues(game, preset, targets, foundation) {
  const target = targetOfPreset(preset.name);
  if (!target) return { header: {}, options: {} };
  const exportPath = path.relative(game.root, targets[target].output).split(path.sep).join("/");
  const options = {};
  if (target === "macOS") options["application/bundle_identifier"] = JSON.stringify(applicationId(game));
  if (target === "Android") {
    options["package/unique_name"] = JSON.stringify(applicationId(game));
    options["version/code"] = String(androidVersionCode(gameVersion(game)));
    Object.assign(options, androidPermissions(game, foundation));
    // The layers of the launcher icon, when the game has them; without them
    // Godot makes the whole icon the foreground, which a launcher cuts down.
    const icon = hasAndroidIcon(game) ? androidIconPaths() : { foreground: "", background: "" };
    options["launcher_icons/adaptive_foreground_432x432"] = JSON.stringify(icon.foreground);
    options["launcher_icons/adaptive_background_432x432"] = JSON.stringify(icon.background);
    for (const key of ["keystore/debug", "keystore/debug_user", "keystore/debug_password", "keystore/release", "keystore/release_user", "keystore/release_password"]) {
      options[key] = '""';
    }
  }
  return { header: { export_path: JSON.stringify(exportPath) }, options };
}

// The export_presets.cfg text as the manifests and the targets say: a preset
// for every target, what follows from the game in each, and every
// exclude_filter the game's own filters, then its addons'; the filters of an
// addon the game no longer links go. The new-game template, which is no game,
// keeps its presets as they are written.
function syncedExportPresets(text, game, foundation = readFoundation()) {
  const sections = parseSections(text);
  if (!game.template) {
    const presets = presetsOf(sections);
    let template = null;
    for (const name of PRESET_NAMES) {
      if (presets.some((preset) => preset.name === name)) continue;
      template = template || templatePresets();
      const source = template.find((preset) => preset.name === name);
      if (!source || !source.options) fail(`tiamat/templates/new_game/export_presets.cfg has no '${name}' preset to give games/${game.id}.`);
      const index = presets.length;
      const header = { name: `preset.${index}`, lines: [...source.header.lines] };
      const options = { name: `preset.${index}.options`, lines: [...source.options.lines] };
      sections.push(header, options);
      presets.push({ name, header, options });
    }
    const targets = targetsFor(game);
    for (const preset of presets) {
      const values = derivedPresetValues(game, preset, targets, foundation);
      for (const [key, value] of Object.entries(values.header)) setValue(sections, preset.header.name, key, value);
      if (!preset.options) continue;
      for (const [key, value] of Object.entries(values.options)) setValue(sections, preset.options.name, key, value);
    }
  }
  const managed = new Set(Object.values(ADDON_EXPORT_EXCLUDES).flat());
  const addons = desiredAddonExcludes(game);
  return formatSections(sections).replace(/^exclude_filter="([^"]*)"$/gm, (_line, filters) => {
    const own = filters.split(",").filter((filter) => filter !== "" && !managed.has(filter));
    return `exclude_filter="${[...own, ...addons].join(",")}"`;
  });
}

// The project.godot text with the build an export is made as ([tiamat]
// build): the commit, and "-dirty" when the files had changes. The game shows
// it beside its version and in its diagnostics (GameDiagnosticsService), so a
// report names the very build. tools/export.js writes it for the export alone.
function stampedProject(text, build) {
  const sections = parseSections(text);
  setValue(sections, "tiamat", "build", JSON.stringify(build));
  return formatSections(sections);
}

// The managed files of the game, as [file, function of their text].
function managedFiles(game, foundation) {
  return [
    [gamePath(game, "project.godot"), (text) => syncedProject(text, game, foundation)],
    [gamePath(game, ".gutconfig.json"), (text) => syncedGutConfig(text, game, foundation)],
    [gamePath(game, "export_presets.cfg"), (text) => syncedExportPresets(text, game, foundation)],
  ];
}

// Writes the managed parts of the game's project.godot, .gutconfig.json and
// export_presets.cfg; returns whether any changed.
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

module.exports = { formatSections, parseSections, poTranslation, stampedProject, desiredAddonExcludes, desiredAutoloads, desiredCatalogs, desiredPlugins, desiredTestDirs, moduleOrder, projectInSync, syncProject, syncedExportPresets, syncedGutConfig, syncedProject };
