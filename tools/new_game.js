#!/usr/bin/env node
// Creates a new game in this repository on the GameBase foundation:
//
//   node tools/new_game.js --id <id> --name "<Game Name>"
//
// It copies gamebase/templates/new_game into games/<id>/ (a project.godot with
// the core autoloads, a game definition, an empty game/game_setup.gd, a content
// database, one start location and a new-game smoke script), names the project,
// writes games/<id>/game.json with no module, and links the foundation in.
// Enable a module by listing it (and the modules it requires) in game.json,
// registering its autoloads in project.godot and wiring it in
// game/game_setup.gd; then run node tools/link.js.
const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { fail, main, rootPath } = require("./lib/common");
const { GAME_ID_RE, GAMES_ROOT, readFoundation } = require("./lib/games");
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

function setProjectValue(text, key, value) {
  const pattern = new RegExp(`^${key}=.*$`, "m");
  if (!pattern.test(text)) fail(`The template project.godot has no ${key}.`);
  return text.replace(pattern, `${key}=${JSON.stringify(value)}`);
}

// Creates the game in games/<id>/, or in `out` for a throwaway check, and
// returns it in the shape of a loaded game.
function createGame({ id, name, out }) {
  if (!GAME_ID_RE.test(String(id || ""))) fail(`Invalid game id '${id}': use lowercase letters, digits and hyphens.`);
  if (!name || !String(name).trim()) fail("A game needs a --name.");
  const root = out ? path.resolve(out) : path.join(GAMES_ROOT, id);
  if (fs.existsSync(root) && fs.readdirSync(root).length > 0) fail(`${root} is not empty.`);
  copyTree(TEMPLATE, root);

  const projectFile = path.join(root, "project.godot");
  let project = fs.readFileSync(projectFile, "utf8");
  project = setProjectValue(project, "config/name", name);
  project = setProjectValue(project, "file_logging/log_path", `user://logs/${id}.log`);
  fs.writeFileSync(projectFile, project, "utf8");
  fs.writeFileSync(path.join(root, "game.json"), `${JSON.stringify({ id, modules: [] }, null, 2)}\n`, "utf8");

  const game = { id, root, modules: [], addons: [...readFoundation().addons].sort() };
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
