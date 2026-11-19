// The layers of a game's Android launcher icon, which
// tools/render_android_icon.js draws from its project icon into
// games/<id>/android_icon/ and tools/link.js names in its Android preset.
const crypto = require("node:crypto");
const fs = require("node:fs");
const { fail } = require("./common");
const { gamePath, projectString } = require("./games");

// Where the layers are, in the game.
const ICON_DIR = "android_icon";
const FOREGROUND = "foreground.png";
const BACKGROUND = "background.png";
const RECORD = "icon.json";
// How the layers are drawn: a change to the drawing that should reach every
// game raises it, and the check asks for them to be drawn again.
const RECIPE = 1;

// The project icon of the game: its res:// path and the file.
function projectIcon(game) {
  const icon = projectString(game, "application", "config/icon");
  if (!icon || !icon.startsWith("res://")) fail(`${gameLabel(game)}/project.godot has no config/icon under res://.`);
  const file = gamePath(game, ...icon.slice("res://".length).split("/"));
  if (!fs.existsSync(file)) fail(`${gameLabel(game)}: its icon ${icon} is missing.`);
  return { icon, file };
}

function gameLabel(game) {
  return game.template ? "tiamat/templates/new_game" : `games/${game.id}`;
}

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

// What icon.json holds for the game's current icon.
function expectedRecord(game) {
  const { icon, file } = projectIcon(game);
  return { icon, sha256: sha256(file), recipe: RECIPE };
}

// Whether the game has its launcher layers.
function hasAndroidIcon(game) {
  return [FOREGROUND, BACKGROUND].every((name) => fs.existsSync(gamePath(game, ICON_DIR, name)));
}

// The res:// paths of the layers, which the Android preset names.
function androidIconPaths() {
  return { foreground: `res://${ICON_DIR}/${FOREGROUND}`, background: `res://${ICON_DIR}/${BACKGROUND}` };
}

// Why the game's layers are not those of its icon now, or null when they are.
function staleAndroidIcon(game) {
  if (!hasAndroidIcon(game)) return `${gameLabel(game)} has no ${ICON_DIR}/ (run node tools/render_android_icon.js)`;
  let record = null;
  try {
    record = JSON.parse(fs.readFileSync(gamePath(game, ICON_DIR, RECORD), "utf8"));
  } catch {
    return `${gameLabel(game)}/${ICON_DIR}/${RECORD} is missing or unreadable (run node tools/render_android_icon.js)`;
  }
  const expected = expectedRecord(game);
  if (record.icon !== expected.icon || record.sha256 !== expected.sha256 || record.recipe !== expected.recipe) {
    return `${gameLabel(game)}: its icon changed since its launcher layers were drawn (run node tools/render_android_icon.js${game.template ? "" : ` --game ${game.id}`})`;
  }
  return null;
}

module.exports = { BACKGROUND, FOREGROUND, ICON_DIR, RECORD, androidIconPaths, expectedRecord, gameLabel, hasAndroidIcon, projectIcon, staleAndroidIcon };
