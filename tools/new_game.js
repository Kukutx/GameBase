#!/usr/bin/env node
// Creates a new game in this repository on the Tiamat foundation:
//
//   node tools/new_game.js --id <id> --name "<Game Name>" [--description "<One line>"]
//     [--modules <module>[,<module>...]]
//
// It copies tiamat/templates/new_game into games/<id>/: a project.godot with
// the core autoloads and the core and game translation catalogs, an export
// preset for every target (tools/lib/targets.js), a game definition, the
// game's own empty GameSetup module (game/game_setup.gd), a player and HUD,
// two locations joined by portals, a first hint and achievement with the
// triggers that show and unlock them, a unit test and a new-game smoke script.
// It names the project, its log, its catalog and its description (the title
// screen's line under the name, with its catalog entry, which keeps the
// English text until it is translated), writes games/<id>/game.json with the
// modules of --modules and every module they require (none without it), and
// links the foundation in, which also writes where each preset exports to and
// the game's application id.
// Enable a module later by listing it (and the modules it requires) in
// game.json, then run node tools/link.js: it links the module and registers
// its autoloads and catalogs in project.godot, and the module installs itself
// (its GameModule class).
const fs = require("node:fs");
const path = require("node:path");
const { fail, main, parseToolArgs, rootPath } = require("./lib/common");
const { GAME_ID_RE, GAMES_ROOT, readFoundation } = require("./lib/games");
const { linkGame } = require("./link");

const TEMPLATE = rootPath("tiamat", "templates", "new_game");
// The template's description, in its project.godot and its catalog.
const TEMPLATE_DESCRIPTION = "New game on Tiamat";

function copyTree(from, to) {
  fs.mkdirSync(to, { recursive: true });
  for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
    const source = path.join(from, entry.name);
    const target = path.join(to, entry.name);
    if (entry.isDirectory()) copyTree(source, target);
    else fs.copyFileSync(source, target);
  }
}

function setValue(text, key, value) {
  const pattern = new RegExp(`^${key}=.*$`, "m");
  if (!pattern.test(text)) fail(`The template project.godot has no ${key}.`);
  return text.replace(pattern, `${key}=${JSON.stringify(value)}`);
}

function rewrite(file, edit) {
  fs.writeFileSync(file, edit(fs.readFileSync(file, "utf8")), "utf8");
}

// The modules `requested` names with every module they require, directly or
// not, in the order of their ids, as a game.json lists them.
function withRequirements(requested, foundation) {
  const modules = new Set();
  const visit = (name, by) => {
    if (!foundation.modules[name]) {
      if (by) fail(`Module ${by} requires ${name}, which tiamat/tiamat.json does not declare.`);
      fail(`Unknown module '${name}'. The modules: ${Object.keys(foundation.modules).sort().join(", ")}.`);
    }
    if (modules.has(name)) return;
    modules.add(name);
    for (const required of foundation.modules[name].requires || []) visit(required, name);
  };
  for (const name of requested) visit(name);
  return [...modules].sort();
}

// Creates the game in games/<id>/, or in `out` for a throwaway check, with
// `modules` and the modules they require, and returns it in the shape of a
// loaded game.
function createGame({ id, name, description, modules: requested = [], out }) {
  if (!GAME_ID_RE.test(String(id || ""))) fail(`Invalid game id '${id}': use lowercase letters, digits and hyphens.`);
  if (!name || !String(name).trim()) fail("A game needs a --name.");
  if (description !== undefined && (!String(description).trim() || /["\\\r\n]/.test(description))) {
    fail("A --description is one line of text without quotes or backslashes.");
  }
  const foundation = readFoundation();
  const modules = withRequirements(requested, foundation);
  const root = out ? path.resolve(out) : path.join(GAMES_ROOT, id);
  if (fs.existsSync(root) && fs.readdirSync(root).length > 0) fail(`${root} is not empty.`);
  copyTree(TEMPLATE, root);

  rewrite(path.join(root, "project.godot"), (text) => {
    text = setValue(text, "config/name", name);
    if (description !== undefined) text = setValue(text, "config/description", description);
    return setValue(text, "file_logging/log_path", `user://logs/${id}.log`);
  });
  rewrite(path.join(root, "game", "i18n", "ui.zh_CN.po"), (text) => {
    text = text.replace(/Project-Id-Version: [^\\]*/, `Project-Id-Version: ${name}`);
    if (description === undefined) return text;
    const entry = new RegExp(`^msgid ${escapeRegExp(JSON.stringify(TEMPLATE_DESCRIPTION))}\\nmsgstr ".*"$`, "m");
    if (!entry.test(text)) fail("The template catalog has no entry for its description.");
    return text.replace(entry, () => `msgid ${JSON.stringify(description)}\nmsgstr ${JSON.stringify(description)}`);
  });
  const manifest = { id, modules };
  fs.writeFileSync(path.join(root, "game.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");

  const addons = new Set([...foundation.addons, ...modules.flatMap((module) => foundation.modules[module].addons || [])]);
  const game = { id, root, modules, addons: [...addons].sort(), manifest };
  linkGame(game);
  return game;
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

module.exports = { createGame, withRequirements };

if (require.main === module) {
  main(() => {
    const { values } = parseToolArgs({ options: { id: { type: "string" }, name: { type: "string" }, description: { type: "string" }, modules: { type: "string" } } });
    if (!values.id || !values.name) fail('Usage: node tools/new_game.js --id <id> --name "<Game Name>" [--description "<One line>"] [--modules <module>[,<module>...]]');
    const modules = (values.modules || "").split(",").map((module) => module.trim()).filter(Boolean);
    const game = createGame({ id: values.id, name: values.name, description: values.description, modules });
    const linked = game.modules.length > 0 ? ` with ${game.modules.join(", ")}` : "";
    console.log(`Created ${values.name} in games/${game.id}${linked}. Validate it with: node tools/validate.js --game ${game.id}`);
  });
}
