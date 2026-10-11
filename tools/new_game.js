#!/usr/bin/env node
// Creates a new game in this repository on the GameBase foundation:
//
//   node tools/new_game.js --id <id> --name "<Game Name>"
//
// It copies gamebase/templates/new_game into games/<id>/: a project.godot with
// the core autoloads and the core and game translation catalogs, the Windows,
// Linux and Web export presets, a game definition, the game's own empty
// GameSetup module (game/game_setup.gd), a content pack with one start
// location, a unit test and a new-game smoke script. It names the project, its
// log, its catalog and its export paths, writes games/<id>/game.json with no
// module, and links the foundation in.
// Enable a module by listing it (and the modules it requires) in game.json,
// then run node tools/link.js: it links the module and registers its autoloads
// and catalogs in project.godot, and the module installs itself (its
// GameModule class).
const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { fail, main, rootPath } = require("./lib/common");
const { GAME_ID_RE, GAMES_ROOT, readFoundation } = require("./lib/games");
const { presetsFor } = require("./export");
const { linkGame } = require("./link");

const TEMPLATE = rootPath("gamebase", "templates", "new_game");

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

// Creates the game in games/<id>/, or in `out` for a throwaway check, and
// returns it in the shape of a loaded game.
function createGame({ id, name, out }) {
  if (!GAME_ID_RE.test(String(id || ""))) fail(`Invalid game id '${id}': use lowercase letters, digits and hyphens.`);
  if (!name || !String(name).trim()) fail("A game needs a --name.");
  const root = out ? path.resolve(out) : path.join(GAMES_ROOT, id);
  if (fs.existsSync(root) && fs.readdirSync(root).length > 0) fail(`${root} is not empty.`);
  copyTree(TEMPLATE, root);

  rewrite(path.join(root, "project.godot"), (text) => {
    text = setValue(text, "config/name", name);
    return setValue(text, "file_logging/log_path", `user://logs/${id}.log`);
  });
  // The editor's default export paths; tools/export.js passes the same ones.
  const outputs = presetsFor({ id, root });
  rewrite(path.join(root, "export_presets.cfg"), (text) =>
    text.replace(/^name="([^"]+)"$([\s\S]*?)^export_path="[^"]*"$/gm, (match, preset, between) => {
      if (!outputs[preset]) fail(`The template export_presets.cfg has an unknown preset '${preset}'.`);
      const relative = path.relative(root, outputs[preset].output).split(path.sep).join("/");
      return `name=${JSON.stringify(preset)}${between}export_path=${JSON.stringify(relative)}`;
    }),
  );
  rewrite(path.join(root, "game", "i18n", "ui.zh_CN.po"), (text) => text.replace(/Project-Id-Version: [^\\]*/, `Project-Id-Version: ${name}`));
  fs.writeFileSync(path.join(root, "game.json"), `${JSON.stringify({ id, modules: [] }, null, 2)}\n`, "utf8");

  const game = { id, root, modules: [], addons: [...readFoundation().addons].sort(), manifest: { id, modules: [] } };
  linkGame(game);
  return game;
}

module.exports = { createGame };

if (require.main === module) {
  main(() => {
    const { values } = parseArgs({ options: { id: { type: "string" }, name: { type: "string" } } });
    if (!values.id || !values.name) fail('Usage: node tools/new_game.js --id <id> --name "<Game Name>"');
    const game = createGame({ id: values.id, name: values.name });
    console.log(`Created ${values.name} in games/${game.id}. Validate it with: node tools/validate.js --game ${game.id}`);
  });
}
