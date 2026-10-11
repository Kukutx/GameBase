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
//   [editor_plugins]       the plugin of every addon the game links.
// Everything else in project.godot belongs to the game.
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

function setValue(sections, name, key, value) {
  const section = sectionOf(sections, name);
  const index = section.lines.findIndex((line) => line.startsWith(`${key}=`));
  if (index >= 0) section.lines[index] = `${key}=${value}`;
  else section.lines.push(`${key}=${value}`);
}

// The project.godot text with the managed parts as the manifests say.
function syncedProject(text, game, foundation = readFoundation()) {
  const sections = parseSections(text);
  sectionOf(sections, "autoload").lines = desiredAutoloads(game, foundation).map(([name, script]) => `${name}="*${script}"`);
  setValue(sections, "internationalization", "locale/translations", packedStrings(desiredCatalogs(game)));
  setValue(sections, "editor_plugins", "enabled", packedStrings(desiredPlugins(game)));
  return formatSections(sections);
}

// Writes the managed parts of the game's project.godot; returns whether it changed.
function syncProject(game, foundation = readFoundation()) {
  const file = gamePath(game, "project.godot");
  const text = fs.readFileSync(file, "utf8");
  const synced = syncedProject(text, game, foundation);
  if (synced === text) return false;
  fs.writeFileSync(file, synced, "utf8");
  return true;
}

// Whether the game's project.godot holds what syncProject() would write.
function projectInSync(game, foundation = readFoundation()) {
  const text = fs.readFileSync(gamePath(game, "project.godot"), "utf8");
  return syncedProject(text, game, foundation) === text;
}

module.exports = { formatSections, parseSections, desiredAutoloads, desiredCatalogs, desiredPlugins, moduleOrder, projectInSync, syncProject, syncedProject };
