#!/usr/bin/env node
// Links the shared foundation and addons into each game project:
//
//   node tools/link.js [--game <id>]
//
// A Godot project only sees files under its own directory, so every game gets
// games/<id>/gamebase/core, games/<id>/gamebase/modules/<module> for each
// module its game.json lists, and games/<id>/addons/<addon> for each addon it
// uses. They are links to the one copy at the repository root (junctions on
// Windows, symbolic links elsewhere), so a change to the foundation reaches
// every game at once. The links are generated and Git-ignored; the validation
// and export tools refresh them before they run Godot. It also writes the parts
// of the game's project.godot that follow from the manifests: the autoloads of
// the core and of the game's modules, the translation catalogs and the addon
// plugins (tools/lib/project.js). Without --game every registered game is
// linked, and the new-game template's project.godot is brought in step too.
const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { fail, main, rootPath } = require("./lib/common");
const { gamePath, resolveGames, templateGame } = require("./lib/games");
const { syncProject } = require("./lib/project");

function isLink(file) {
  try {
    return fs.lstatSync(file).isSymbolicLink();
  } catch {
    return false;
  }
}

function linkTarget(file) {
  return path.resolve(path.dirname(file), fs.readlinkSync(file));
}

// Creates or corrects one link. A real file or directory in its place is left
// alone and reported, so linking never deletes work.
function ensureLink(link, target) {
  if (isLink(link)) {
    if (linkTarget(link) === target) return false;
    fs.unlinkSync(link);
  } else if (fs.existsSync(link)) {
    fail(`${path.relative(rootPath(), link)} is a real directory where tools/link.js places a link to ${path.relative(rootPath(), target)}. Move its content into the shared copy and delete it.`);
  }
  fs.mkdirSync(path.dirname(link), { recursive: true });
  if (process.platform === "win32") {
    fs.symlinkSync(target, link, "junction");
  } else {
    fs.symlinkSync(path.relative(path.dirname(link), target), link, "dir");
  }
  return true;
}

// Removes the links in a directory that the game no longer uses.
function pruneLinks(directory, keep) {
  if (!fs.existsSync(directory)) return;
  for (const entry of fs.readdirSync(directory)) {
    const file = path.join(directory, entry);
    if (!keep.has(entry) && isLink(file)) fs.unlinkSync(file);
  }
}

function desiredLinks(game) {
  const links = [[gamePath(game, "gamebase", "core"), rootPath("gamebase", "core")]];
  for (const module of game.modules) {
    links.push([gamePath(game, "gamebase", "modules", module), rootPath("gamebase", "modules", module)]);
  }
  for (const addon of game.addons) {
    links.push([gamePath(game, "addons", addon), rootPath("addons", addon)]);
  }
  return links;
}

function linkGame(game) {
  let changed = 0;
  for (const [link, target] of desiredLinks(game)) {
    if (ensureLink(link, target)) changed += 1;
  }
  pruneLinks(gamePath(game, "gamebase", "modules"), new Set(game.modules));
  pruneLinks(gamePath(game, "addons"), new Set(game.addons));
  if (syncProject(game)) changed += 1;
  return changed;
}

module.exports = { linkGame, desiredLinks, isLink };

if (require.main === module) {
  main(() => {
    const { values } = parseArgs({ options: { game: { type: "string", multiple: true } } });
    for (const game of resolveGames(values.game || [])) {
      const changed = linkGame(game);
      console.log(`${game.id}: foundation core, ${game.modules.length} module(s) and ${game.addons.length} addon(s) linked${changed ? ` (${changed} updated)` : ""}.`);
    }
    if (!values.game && syncProject(templateGame())) console.log("gamebase/templates/new_game/project.godot and .gutconfig.json updated.");
  });
}
