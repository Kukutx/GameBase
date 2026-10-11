#!/usr/bin/env node
// Creates a new game project on the GameBase foundation:
//
//   node tools/new_game.js --out ../MyGame --name "My Game" [--from .]
//
// It installs the foundation core with gamebase_sync.js (so the new project
// gets a gamebase.lock.json), writes project.godot with the core autoloads, and
// copies the minimal game from gamebase/templates/new_game: a game definition,
// an empty game_setup.gd, a content database and one location scene. Enable a
// module by adding its autoloads to project.godot and registering it in
// game/game_setup.gd; install modules with gamebase_sync.js --modules.

const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { install } = require("./gamebase_sync");

const TEMPLATE = "gamebase/templates/new_game";
// Autoloads the template implements in its own game/ directory.
const GAME_AUTOLOADS = {
  ContentDB: "res://game/content/game_content_database.gd",
  GameSetup: "res://game/game_setup.gd",
};

function copyTree(from, to) {
  for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
    if (entry.name === ".gdignore") continue; // keeps the template out of GameBase's own project
    const source = path.join(from, entry.name);
    const target = path.join(to, entry.name);
    if (entry.isDirectory()) {
      fs.mkdirSync(target, { recursive: true });
      copyTree(source, target);
    } else {
      fs.copyFileSync(source, target);
    }
  }
}

// The foundation's project.godot with the game's name, scene and autoloads:
// core autoloads stay, module autoloads go, and the game's own are replaced.
function projectSettings(source, name) {
  const lines = fs.readFileSync(path.join(source, "project.godot"), "utf8").split(/\r?\n/);
  const output = [];
  let section = "";
  for (const line of lines) {
    const header = line.match(/^\[(.+)\]$/);
    if (header) section = header[1];
    if (section === "application") {
      if (line.startsWith("config/name=")) {
        output.push(`config/name=${JSON.stringify(name)}`);
        continue;
      }
      if (line.startsWith("config/version=")) {
        output.push('config/version="0.1.0"');
        continue;
      }
      if (line.startsWith("run/main_scene=")) {
        output.push('run/main_scene="res://game/world/start.tscn"');
        continue;
      }
      if (line.startsWith("config/icon=")) continue;
    }
    if (section === "autoload") {
      const autoload = line.match(/^(\w+)="\*res:\/\/(.+)"$/);
      if (autoload) {
        const [, key, file] = autoload;
        if (GAME_AUTOLOADS[key]) output.push(`${key}="*${GAME_AUTOLOADS[key]}"`);
        else if (file.startsWith("gamebase/core/") || file.startsWith("addons/")) output.push(line);
        continue;
      }
    }
    if (section === "internationalization" && line.startsWith("locale/")) continue;
    if (section === "debug" && line.startsWith("file_logging/log_path=")) {
      output.push(`file_logging/log_path="user://logs/game.log"`);
      continue;
    }
    output.push(line);
  }
  return output.join("\n");
}

function createGame({ out, name, from }) {
  const source = path.resolve(from);
  const target = path.resolve(out);
  if (fs.existsSync(target) && fs.readdirSync(target).length > 0) throw new Error(`${target} is not empty`);
  fs.mkdirSync(target, { recursive: true });
  const result = install({ from: source, project: target, modules: [] });
  copyTree(path.join(source, TEMPLATE), target);
  fs.writeFileSync(path.join(target, "project.godot"), projectSettings(source, name));
  for (const file of [".gutconfig.json", "default_bus_layout.tres"]) {
    if (fs.existsSync(path.join(source, file))) fs.copyFileSync(path.join(source, file), path.join(target, file));
  }
  fs.writeFileSync(path.join(target, ".game-version"), "0.1.0\n");
  fs.writeFileSync(path.join(target, ".gitignore"), ".godot/\n*.translation\nnode_modules/\n");
  return result;
}

function runCli(argv = process.argv.slice(2)) {
  const { values } = parseArgs({
    args: argv,
    options: { out: { type: "string" }, name: { type: "string" }, from: { type: "string", default: path.resolve(__dirname, "..") } },
  });
  try {
    if (!values.out || !values.name) throw new Error('usage: new_game.js --out <dir> --name "<Game Name>" [--from <GameBase checkout>]');
    const result = createGame(values);
    console.log(`Created ${values.name} on GameBase ${result.version} in ${path.resolve(values.out)}.`);
    return 0;
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    return 1;
  }
}

module.exports = { createGame, projectSettings };

if (require.main === module) {
  process.exitCode = runCli();
}
