// The game registry of the monorepo. Every directory games/<id>/ with a
// game.json is a game: its own Godot project on the shared foundation in
// gamebase/ and the shared addons in addons/. A game-scoped tool takes
// --game <id>, else the GAMEBASE_GAME environment variable; with a single
// registered game it needs neither. Repository-wide checks walk every game.
const fs = require("node:fs");
const path = require("node:path");
const { GAME_VERSION_RE, fail, rootPath } = require("./common");

const GAMES_ROOT = rootPath("games");
const FOUNDATION_MANIFEST = rootPath("gamebase", "gamebase.json");
const GAME_ID_RE = /^[a-z][a-z0-9-]*$/;
const GAME_KEYS = new Set(["id", "modules", "addons", "licensed_art"]);

function readJson(file, label) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8").replace(/^﻿/, ""));
  } catch (error) {
    return fail(`Could not read ${label}: ${error.message}`);
  }
}

function assertStringList(value, label) {
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== "string" || !entry)) {
    fail(`${label} must be a list of names.`);
  }
  if (new Set(value).size !== value.length) fail(`${label} lists a name twice.`);
  return value;
}

// gamebase/gamebase.json: the modules, the modules each one requires, the
// shared addons each one uses, and the addons every game links (the test
// framework).
function readFoundation() {
  const manifest = readJson(FOUNDATION_MANIFEST, "gamebase/gamebase.json");
  const modules = manifest.modules || {};
  for (const [name, module] of Object.entries(modules)) {
    assertStringList(module.requires || [], `gamebase.json modules.${name}.requires`);
    assertStringList(module.addons || [], `gamebase.json modules.${name}.addons`);
    for (const required of module.requires || []) {
      if (!modules[required]) fail(`gamebase.json modules.${name} requires unknown module ${required}.`);
    }
  }
  return { modules, addons: assertStringList(manifest.addons || [], "gamebase.json addons") };
}

function listGameIds() {
  if (!fs.existsSync(GAMES_ROOT)) return [];
  return fs
    .readdirSync(GAMES_ROOT, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && fs.existsSync(path.join(GAMES_ROOT, entry.name, "game.json")))
    .map((entry) => entry.name)
    .sort();
}

function loadGame(id) {
  if (!GAME_ID_RE.test(String(id))) fail(`Invalid game id '${id}': use lowercase letters, digits and hyphens.`);
  const root = path.join(GAMES_ROOT, id);
  const manifestFile = path.join(root, "game.json");
  if (!fs.existsSync(manifestFile)) fail(`Unknown game '${id}'. Registered games: ${listGameIds().join(", ") || "(none)"}.`);
  const label = `games/${id}/game.json`;
  const manifest = readJson(manifestFile, label);
  for (const key of Object.keys(manifest)) {
    if (!GAME_KEYS.has(key)) fail(`${label} has an unsupported key '${key}'.`);
  }
  if (manifest.id !== id) fail(`${label} id must equal its directory name '${id}'.`);
  if (!fs.existsSync(path.join(root, "project.godot"))) fail(`games/${id} has no project.godot.`);

  const foundation = readFoundation();
  const modules = assertStringList(manifest.modules || [], `${label} modules`);
  for (const module of modules) {
    if (!foundation.modules[module]) fail(`${label} lists unknown module ${module}.`);
    for (const required of foundation.modules[module].requires || []) {
      if (!modules.includes(required)) fail(`${label}: module ${module} requires ${required}; list it in modules.`);
    }
  }
  const addons = new Set([
    ...foundation.addons,
    ...modules.flatMap((module) => foundation.modules[module].addons || []),
    ...assertStringList(manifest.addons || [], `${label} addons`),
  ]);
  for (const addon of addons) {
    if (!fs.existsSync(rootPath("addons", addon, "plugin.cfg"))) fail(`${label} uses addon ${addon}, which addons/ does not hold.`);
  }
  return { id, root, modules, addons: [...addons].sort(), manifest };
}

// The game a game-scoped tool acts on: the explicit id, else GAMEBASE_GAME,
// else the only registered game.
function resolveGame(explicit) {
  const requested = String(explicit || process.env.GAMEBASE_GAME || "").trim();
  const ids = listGameIds();
  if (requested) return loadGame(requested);
  if (ids.length === 1) return loadGame(ids[0]);
  if (ids.length === 0) fail("No game is registered under games/<id>/game.json.");
  return fail(`Several games are registered (${ids.join(", ")}). Choose one with --game <id> or GAMEBASE_GAME.`);
}

// The games a repository-wide step covers: the requested ones, else all of
// them. GAMEBASE_GAME picks the game of a single-game tool and never narrows a
// repository-wide step.
function resolveGames(explicit = []) {
  const requested = explicit.length > 0 ? explicit : listGameIds();
  if (requested.length === 0) fail("No game is registered under games/<id>/game.json.");
  return requested.map((id) => loadGame(String(id).trim()));
}

function gamePath(game, ...parts) {
  return path.join(game.root, ...parts);
}

function readProject(game) {
  return fs.readFileSync(gamePath(game, "project.godot"), "utf8");
}

// A value of project.godot as written: `[section]` then `key=value`.
function projectSetting(game, section, key) {
  let current = "";
  for (const line of readProject(game).split(/\r?\n/)) {
    const header = /^\[(.+)\]$/.exec(line);
    if (header) {
      current = header[1];
    } else if (current === section && line.startsWith(`${key}=`)) {
      return line.slice(key.length + 1);
    }
  }
  return null;
}

function projectString(game, section, key) {
  const raw = projectSetting(game, section, key);
  const match = raw === null ? null : /^"([^"]*)"$/.exec(raw);
  return match ? match[1] : null;
}

// The game's name: `config/name` in its project.godot.
function gameName(game) {
  const name = projectString(game, "application", "config/name");
  if (!name || !name.trim()) fail(`games/${game.id}/project.godot has no config/name.`);
  return name;
}

// The game's version: `config/version` in its project.godot, the only place it is kept.
function gameVersion(game) {
  const version = projectString(game, "application", "config/version");
  if (!version || !GAME_VERSION_RE.test(version)) {
    fail(`games/${game.id}/project.godot config/version must be a semantic version such as 0.1.0; found '${version}'.`);
  }
  return version;
}

// The file-safe form of the game's name: executables, packs and release
// packages are named after it (Farm1.exe, Farm1-web.zip).
function artifactName(game) {
  const name = gameName(game).replace(/[^A-Za-z0-9_-]+/g, "");
  if (!name) fail(`games/${game.id} config/name "${gameName(game)}" has no letters or digits to name build artifacts after.`);
  return name;
}

// Outputs live outside the game projects, one directory per game.
function buildPath(game, ...parts) {
  return rootPath("build", game.id, ...parts);
}

function distPath(game, ...parts) {
  return rootPath("dist", game.id, ...parts);
}

function artifactsPath(game, ...parts) {
  return rootPath("artifacts", game.id, ...parts);
}

// A release tag names one game: game/<id>/v<version>.
function parseReleaseTag(tag) {
  const match = /^game\/([a-z][a-z0-9-]*)\/v(.+)$/.exec(String(tag || ""));
  return match ? { id: match[1], version: match[2] } : null;
}

function releaseTag(game, version) {
  return `game/${game.id}/v${version}`;
}

module.exports = {
  GAMES_ROOT,
  GAME_ID_RE,
  readFoundation,
  listGameIds,
  loadGame,
  resolveGame,
  resolveGames,
  gamePath,
  readProject,
  projectSetting,
  projectString,
  gameName,
  gameVersion,
  artifactName,
  buildPath,
  distPath,
  artifactsPath,
  parseReleaseTag,
  releaseTag,
};
