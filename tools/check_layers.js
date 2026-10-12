#!/usr/bin/env node
// Enforces the dependency direction of the monorepo:
//   gamebase/core         may not use a module, an addon or a game;
//   gamebase/modules/<m>  may not use a game, and may use only the modules and
//                         addons gamebase/gamebase.json lists for it, whose
//                         requires form no cycle, so a game can take a module
//                         with only the modules below it;
//   games/<id>/           may use the core, and only the modules and addons its
//                         game.json lists (the addons of gamebase.json and of
//                         those modules come with them);
// and no foundation file may name a content id of any game: an id a game gives
// to `id` or to a `*_id` property in its data and scenes. A script "uses" the
// core, a module or a game when it names one of its autoloads or class_names
// or a res:// path in it, and an addon when it names a res://addons/<addon>/
// path; a game's project.godot uses the scripts and plugins it registers.

const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function walk(dir, extensions, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    // The links tools/link.js creates inside a game point back at the shared copy.
    if (entry.isSymbolicLink()) continue;
    if (entry.isDirectory()) walk(full, extensions, out);
    else if (extensions.some((ext) => entry.name.endsWith(ext))) out.push(full);
  }
  return out;
}

function rel(root, file) {
  return path.relative(root, file).split(path.sep).join("/");
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

// The layer of a repository file.
function layerOf(file) {
  if (file.startsWith("gamebase/core/")) return "core";
  if (file.startsWith("gamebase/modules/")) return `module:${file.split("/")[2]}`;
  if (file.startsWith("games/")) return `game:${file.split("/")[1]}`;
  return "other";
}

// The layer of a res:// path seen from a project file; `game` is the id of the
// game the file belongs to, or null for the foundation.
function resLayer(resPath, game) {
  if (resPath.startsWith("gamebase/core/")) return "core";
  if (resPath.startsWith("gamebase/modules/")) return `module:${resPath.split("/")[2]}`;
  if (resPath.startsWith("addons/")) return `addon:${resPath.split("/")[1]}`;
  if (resPath.startsWith("game/") || resPath.startsWith("test/")) return game ? `game:${game}` : "game";
  return "other";
}

// Whether code in layer `from` may depend on layer `to`. Which modules and
// addons are declared is checked separately.
function allowed(from, to) {
  if (to === "other" || from === to) return true;
  if (from === "core") return to === "core";
  if (from.startsWith("module:")) return to === "core" || to.startsWith("module:") || to.startsWith("addon:");
  if (from.startsWith("game:")) return to === "core" || to.startsWith("module:") || to.startsWith("addon:");
  return true;
}

function stripComments(source) {
  return source
    .split("\n")
    .map((line) => {
      let quoted = null;
      for (let i = 0; i < line.length; i += 1) {
        const c = line[i];
        if (quoted) {
          if (c === "\\") i += 1;
          else if (c === quoted) quoted = null;
        } else if (c === '"' || c === "'") quoted = c;
        else if (c === "#") return line.slice(0, i);
      }
      return line;
    })
    .join("\n");
}

function classNameOf(file) {
  const match = fs.readFileSync(file, "utf8").match(/^class_name\s+(\w+)/m);
  return match ? match[1] : null;
}

function readFoundation(root) {
  const manifest = readJson(path.join(root, "gamebase", "gamebase.json")) || {};
  return { modules: manifest.modules || {}, addons: manifest.addons || [] };
}

function readGames(root, foundation) {
  const gamesRoot = path.join(root, "games");
  if (!fs.existsSync(gamesRoot)) return [];
  return fs
    .readdirSync(gamesRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && fs.existsSync(path.join(gamesRoot, entry.name, "game.json")))
    .map((entry) => {
      const id = entry.name;
      const manifest = readJson(path.join(gamesRoot, id, "game.json")) || {};
      const modules = Array.isArray(manifest.modules) ? manifest.modules : [];
      const addons = new Set([
        ...foundation.addons,
        ...modules.flatMap((module) => (foundation.modules[module] && foundation.modules[module].addons) || []),
        ...(Array.isArray(manifest.addons) ? manifest.addons : []),
      ]);
      const projectFile = path.join(gamesRoot, id, "project.godot");
      const project = fs.existsSync(projectFile) ? fs.readFileSync(projectFile, "utf8") : "";
      return { id, dir: `games/${id}`, modules: new Set(modules), addons, project };
    })
    .sort((a, b) => a.id.localeCompare(b.id));
}

// res://path inside a game project -> repository path.
function repoPath(game, resPath) {
  return resPath.startsWith("game/") || resPath.startsWith("test/") ? `${game.dir}/${resPath}` : resPath;
}

function collectModel(root) {
  const foundation = readFoundation(root);
  const games = readGames(root, foundation);
  const classes = new Map(); // class_name -> repository file (foundation)
  for (const file of walk(path.join(root, "gamebase", "core"), [".gd"]).concat(walk(path.join(root, "gamebase", "modules"), [".gd"]))) {
    const name = classNameOf(file);
    if (name) classes.set(name, rel(root, file));
  }
  for (const game of games) {
    game.classes = new Map(); // class_name -> repository file
    for (const file of walk(path.join(root, game.dir, "game"), [".gd"]).concat(walk(path.join(root, game.dir, "test"), [".gd"]))) {
      const name = classNameOf(file);
      if (name) game.classes.set(name, rel(root, file));
    }
    game.autoloads = new Map(); // name -> { file, layer }
    for (const match of game.project.matchAll(/^(\w+)="\*res:\/\/([^"]+\.gd)"$/gm)) {
      const [, name, resPath] = match;
      game.autoloads.set(name, { file: repoPath(game, resPath), layer: resLayer(resPath, game.id) });
    }
  }
  return { foundation, games, classes };
}

// The layers a symbol has from the foundation's point of view: its class or
// the scripts the games register under that autoload name.
function foundationSymbols(model) {
  const symbols = new Map(); // name -> Set of layers
  const add = (name, layer) => (symbols.get(name) || symbols.set(name, new Set()).get(name)).add(layer);
  for (const [name, file] of model.classes) add(name, layerOf(file));
  for (const game of model.games) {
    for (const name of game.classes.keys()) add(name, "game");
    for (const [name, autoload] of game.autoloads) add(name, autoload.layer.startsWith("game:") ? "game" : autoload.layer);
  }
  return symbols;
}

// The ids the games define or name in their data and scenes: content entries,
// locations, spawn points, housings, containers and the like.
function collectContentIds(root, games) {
  const ids = new Set();
  for (const game of games) {
    for (const file of walk(path.join(root, game.dir, "game"), [".tres", ".tscn"])) {
      for (const match of fs.readFileSync(file, "utf8").matchAll(/^(?:\w+_)?id = &"([^"]+)"$/gm)) ids.add(match[1]);
    }
  }
  return ids;
}

// The id literals of a foundation file: any lowercase string in a script, and
// the StringNames of a scene or resource.
function idLiterals(raw, isScript) {
  const pattern = isScript ? /&?"([a-z][a-z0-9_]*)"/g : /&"([a-z][a-z0-9_]*)"/g;
  return [...(isScript ? stripComments(raw) : raw).matchAll(pattern)].map((match) => match[1]);
}

// What one file uses: layers of the res:// paths and of the symbols it names.
function usesOf(raw, isScript, symbolLayers, game) {
  const used = [];
  for (const match of raw.matchAll(/res:\/\/([\w./-]+)/g)) used.push({ what: `path:${match[1]}`, layer: resLayer(match[1], game) });
  if (isScript) {
    for (const word of new Set(stripComments(raw).match(/\b[A-Z]\w*\b/g) || [])) {
      for (const layer of symbolLayers(word)) used.push({ what: word, layer });
    }
  }
  return used;
}

function checkFoundation(root, model, problems) {
  const symbols = foundationSymbols(model);
  const contentIds = collectContentIds(root, model.games);
  for (const file of walk(path.join(root, "gamebase", "core"), [".gd", ".tscn", ".tres"]).concat(walk(path.join(root, "gamebase", "modules"), [".gd", ".tscn", ".tres"]))) {
    const relative = rel(root, file);
    const from = layerOf(relative);
    const raw = fs.readFileSync(file, "utf8");
    const isScript = relative.endsWith(".gd");
    const module = from.startsWith("module:") ? from.slice("module:".length) : null;
    const declared = module ? model.foundation.modules[module] : null;
    const reported = new Set();
    for (const use of usesOf(raw, isScript, (word) => symbols.get(word) || [], null)) {
      if (!allowed(from, use.layer)) {
        reported.add(`${relative} (${from}) must not use ${use.what}`);
      } else if (declared && use.layer.startsWith("module:") && use.layer !== from && !(declared.requires || []).includes(use.layer.slice(7))) {
        reported.add(`gamebase/modules/${module} uses module ${use.layer.slice(7)}, which gamebase/gamebase.json does not list in its requires (${relative})`);
      } else if (declared && use.layer.startsWith("addon:") && !(declared.addons || []).includes(use.layer.slice(6))) {
        reported.add(`gamebase/modules/${module} uses addon ${use.layer.slice(6)}, which gamebase/gamebase.json does not list in its addons (${relative})`);
      }
    }
    if (module && !declared) reported.add(`gamebase/modules/${module} is not listed under "modules" in gamebase/gamebase.json`);
    for (const literal of idLiterals(raw, isScript)) {
      if (contentIds.has(literal)) reported.add(`${relative} (${from}) must not use literal:${literal}`);
    }
    for (const problem of reported) problems.add(problem);
  }
  for (const [module, entry] of Object.entries(model.foundation.modules)) {
    if (!fs.existsSync(path.join(root, "gamebase", "modules", module))) problems.add(`gamebase/gamebase.json lists module ${module}, which does not exist`);
    for (const required of entry.requires || []) {
      if (!model.foundation.modules[required]) problems.add(`gamebase/gamebase.json: module ${module} requires unknown module ${required}`);
    }
    for (const addon of entry.addons || []) {
      if (!fs.existsSync(path.join(root, "addons", addon))) problems.add(`gamebase/gamebase.json: module ${module} uses addon ${addon}, which addons/ does not hold`);
    }
  }
  const cycle = findRequireCycle(model.foundation.modules);
  if (cycle) problems.add(`gamebase/gamebase.json: modules require each other in a cycle (${cycle.join(" -> ")}); move the shared part down or invert the dependency`);
}

// The first cycle in the modules' requires, as the module names around it
// (the first repeated at the end), or null.
function findRequireCycle(modules) {
  const state = new Map();
  const stack = [];
  const visit = (name) => {
    if (state.get(name) === "done") return null;
    if (state.get(name) === "open") return stack.slice(stack.indexOf(name)).concat(name);
    state.set(name, "open");
    stack.push(name);
    for (const required of modules[name].requires || []) {
      if (!modules[required]) continue;
      const cycle = visit(required);
      if (cycle) return cycle;
    }
    stack.pop();
    state.set(name, "done");
    return null;
  };
  for (const name of Object.keys(modules).sort()) {
    const cycle = visit(name);
    if (cycle) return cycle;
  }
  return null;
}

function checkGame(root, model, game, problems) {
  const label = `${game.dir}/game.json`;
  for (const module of game.modules) {
    const entry = model.foundation.modules[module];
    if (!entry) {
      problems.add(`${label} lists unknown module ${module}`);
      continue;
    }
    for (const required of entry.requires || []) {
      if (!game.modules.has(required)) problems.add(`${label}: module ${module} requires ${required}; list it in modules`);
    }
  }
  for (const addon of game.addons) {
    if (!fs.existsSync(path.join(root, "addons", addon))) problems.add(`${label} uses addon ${addon}, which addons/ does not hold`);
  }

  const symbolLayers = (word) => {
    if (game.autoloads.has(word)) return [game.autoloads.get(word).layer];
    if (game.classes.has(word)) return [`game:${game.id}`];
    if (model.classes.has(word)) return [layerOf(model.classes.get(word))];
    return [];
  };
  const checkUse = (relative, use) => {
    if (!allowed(`game:${game.id}`, use.layer)) {
      problems.add(`${relative} (game:${game.id}) must not use ${use.what}`);
    } else if (use.layer.startsWith("module:") && !game.modules.has(use.layer.slice(7))) {
      problems.add(`${relative} uses ${use.what} from module ${use.layer.slice(7)}, which ${label} does not list`);
    } else if (use.layer.startsWith("addon:") && !game.addons.has(use.layer.slice(6))) {
      problems.add(`${relative} uses ${use.what} from addon ${use.layer.slice(6)}, which ${label} does not list`);
    }
  };
  const files = walk(path.join(root, game.dir, "game"), [".gd", ".tscn", ".tres"]).concat(walk(path.join(root, game.dir, "test"), [".gd", ".tscn", ".tres"]));
  for (const file of files) {
    const relative = rel(root, file);
    for (const use of usesOf(fs.readFileSync(file, "utf8"), relative.endsWith(".gd"), symbolLayers, game.id)) checkUse(relative, use);
  }
  for (const use of usesOf(game.project, false, () => [], game.id)) checkUse(`${game.dir}/project.godot`, use);
}

function checkLayers(root = ROOT) {
  const model = collectModel(root);
  const problems = new Set();
  checkFoundation(root, model, problems);
  for (const game of model.games) {
    checkGame(root, model, game, problems);
  }
  return [...problems];
}

function runCli() {
  const problems = checkLayers();
  if (problems.length > 0) {
    for (const problem of problems) console.error(`ERROR: ${problem}`);
    console.error(`Layer check failed with ${problems.length} problem(s). See gamebase/README.md.`);
    return 1;
  }
  console.log("Layer dependencies OK.");
  return 0;
}

module.exports = { checkLayers, layerOf, resLayer, allowed, stripComments, runCli };

if (require.main === module) {
  process.exitCode = runCli();
}
