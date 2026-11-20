#!/usr/bin/env node
// Lists content files in a game's content pack:
//
//   node tools/add_content.js --game <id> <file>...
//   node tools/add_content.js --game <id> --missing
//
// A content entry (a resource whose script extends ContentEntry: an item, a
// trigger, an achievement) is part of a game only once a content pack its
// GameDefinition names lists it: an ext_resource line and an entry in
// `entries`, with `load_steps` counted when the pack counts them. The tool
// writes those for each file (a path under the game, or res://...), in the pack
// whose folder holds it, and leaves a file the pack lists as it is.
// --missing adds every content file beside a pack (in its folder or the
// folders under it) that no pack lists: what the core's test_content_listed
// reports.
const fs = require("node:fs");
const path = require("node:path");
const { fail, main, parseToolArgs, rootPath } = require("./lib/common");
const { gamePath, projectString, resolveGame } = require("./lib/games");

const EXT_RE = /^\[ext_resource [^\]]*\]$/gm;
const ENTRIES_RE = /^entries = \[(.*)\]$/m;

function attribute(header, name) {
  const match = new RegExp(`\\b${name}="([^"]*)"`).exec(header);
  return match ? match[1] : null;
}

// The ext_resource lines of a .tres or .tscn: each its path and id.
function extResources(text) {
  return (text.match(EXT_RE) || []).map((line) => ({ path: attribute(line, "path"), id: attribute(line, "id"), line }));
}

// The res:// paths of the entries `pack` (a ContentPack's text) lists.
function listedPaths(pack) {
  const entries = ENTRIES_RE.exec(pack);
  if (!entries) return new Set();
  const ids = new Set([...entries[1].matchAll(/ExtResource\("([^"]+)"\)/g)].map((match) => match[1]));
  return new Set(extResources(pack).filter((ext) => ids.has(ext.id)).map((ext) => ext.path));
}

// An ext_resource id for `resPath` in a pack in `folder`: its path under the
// folder without the extension, `_` for what is not a letter, digit or `_`,
// and a number after it while `taken` holds it.
function extId(resPath, folder, taken) {
  const relative = resPath.startsWith(`${folder}/`) ? resPath.slice(folder.length + 1) : resPath.replace(/^res:\/\//, "");
  const base = relative.replace(/\.[^./]+$/, "").replace(/[^A-Za-z0-9_]/g, "_");
  let id = base;
  for (let number = 2; taken.has(id); number++) id = `${base}_${number}`;
  return id;
}

// `pack` with each of `resPaths` it does not list yet listed last: its
// ext_resource line after the others, its entry at the end of `entries`, and
// `load_steps` counted again where the pack counts them.
function addToPack(pack, resPaths, folder) {
  if (!ENTRIES_RE.test(pack)) fail("The content pack has no `entries = [...]` line.");
  const listed = listedPaths(pack);
  const existing = extResources(pack);
  const taken = new Set(existing.map((ext) => ext.id));
  const byPath = new Map(existing.map((ext) => [ext.path, ext.id]));
  const lines = [];
  const refs = [];
  for (const resPath of resPaths) {
    if (listed.has(resPath) || refs.includes(byPath.get(resPath))) continue;
    let id = byPath.get(resPath);
    if (!id) {
      id = extId(resPath, folder, taken);
      taken.add(id);
      byPath.set(resPath, id);
      lines.push(`[ext_resource type="Resource" path="${resPath}" id="${id}"]`);
    }
    refs.push(id);
  }
  if (refs.length === 0) return pack;
  let text = pack;
  if (lines.length > 0) {
    // After the last ext_resource line, or the header of a pack with none.
    const last = existing[existing.length - 1];
    const at = last ? text.indexOf(last.line) + last.line.length : text.indexOf("\n") + 1;
    text = last ? `${text.slice(0, at)}\n${lines.join("\n")}${text.slice(at)}` : `${text.slice(0, at)}\n${lines.join("\n")}\n${text.slice(at)}`;
  }
  text = text.replace(ENTRIES_RE, (line, inside) => {
    const added = refs.map((id) => `ExtResource("${id}")`).join(", ");
    return `entries = [${inside.trim() ? `${inside}, ${added}` : added}]`;
  });
  return text.replace(/^(\[gd_resource [^\]]*\bload_steps=)(\d+)/m, (all, start) => {
    const steps = (text.match(EXT_RE) || []).length + (text.match(/^\[sub_resource /gm) || []).length + 1;
    return `${start}${steps}`;
  });
}

// The classes that extend ContentEntry, directly or not, among `scripts`
// (each a GDScript's text).
function contentClasses(scripts) {
  const parents = new Map();
  for (const script of scripts) {
    const name = /^class_name\s+(\w+)/m.exec(script);
    const parent = /^extends\s+(\w+)/m.exec(script);
    if (name && parent) parents.set(name[1], parent[1]);
  }
  const found = new Set();
  const isContent = (name, seen = new Set()) => {
    if (name === "ContentEntry") return true;
    if (!parents.has(name) || seen.has(name)) return false;
    seen.add(name);
    return isContent(parents.get(name), seen);
  };
  for (const name of parents.keys()) if (isContent(name)) found.add(name);
  return found;
}

function filesUnder(directory, extension) {
  if (!fs.existsSync(directory)) return [];
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...filesUnder(full, extension));
    else if (entry.name.endsWith(extension)) files.push(full);
  }
  return files.sort();
}

// The content packs the game's definition names: each its res:// path, its
// folder and its file.
function gamePacks(game) {
  const definitionPath = projectString(game, "tiamat", "game_definition");
  if (!definitionPath) fail(`games/${game.id}/project.godot names no tiamat/game_definition.`);
  const definition = fs.readFileSync(toFile(game, definitionPath), "utf8");
  const content = /^content = \[(.*)\]$/m.exec(definition);
  const ids = new Set(content ? [...content[1].matchAll(/ExtResource\("([^"]+)"\)/g)].map((match) => match[1]) : []);
  const packs = extResources(definition).filter((ext) => ids.has(ext.id)).map((ext) => ({
    resPath: ext.path,
    folder: ext.path.slice(0, ext.path.lastIndexOf("/")),
    file: toFile(game, ext.path),
  }));
  if (packs.length === 0) fail(`${definitionPath} names no content pack.`);
  return packs;
}

function toFile(game, resPath) {
  if (!resPath.startsWith("res://")) fail(`${resPath} is not a res:// path.`);
  return gamePath(game, ...resPath.slice("res://".length).split("/"));
}

function toResPath(game, file) {
  if (file.startsWith("res://")) return file;
  const relative = path.relative(game.root, path.resolve(file)).split(path.sep).join("/");
  if (relative.startsWith("..") || path.isAbsolute(relative)) fail(`${file} is not in games/${game.id}.`);
  return `res://${relative}`;
}

// The pack whose folder holds `resPath`, the deepest when several do.
function packFor(packs, resPath) {
  const holding = packs.filter((pack) => resPath.startsWith(`${pack.folder}/`));
  if (holding.length === 0) fail(`${resPath} is in the folder of no content pack (${packs.map((pack) => pack.folder).join(", ")}).`);
  return holding.sort((a, b) => b.folder.length - a.folder.length)[0];
}

// The content files beside the packs that no pack lists.
function missingContent(game, packs) {
  const scripts = [rootPath("tiamat"), game.root].flatMap((root) => filesUnder(root, ".gd")).map((file) => fs.readFileSync(file, "utf8"));
  const classes = contentClasses(scripts);
  const listed = new Set(packs.flatMap((pack) => [...listedPaths(fs.readFileSync(pack.file, "utf8"))]));
  const missing = [];
  for (const pack of packs) {
    for (const file of filesUnder(path.dirname(pack.file), ".tres")) {
      const resPath = toResPath(game, file);
      if (resPath === pack.resPath || listed.has(resPath)) continue;
      const header = fs.readFileSync(file, "utf8").split("\n", 1)[0];
      if (classes.has(attribute(header, "script_class"))) missing.push(resPath);
    }
  }
  return [...new Set(missing)];
}

// Lists `files` (or, with `missing`, every content file no pack lists) in
// the game's packs; the res:// paths it added.
function addContent({ game, files = [], missing = false }) {
  const packs = gamePacks(game);
  const resPaths = missing ? missingContent(game, packs) : files.map((file) => toResPath(game, file));
  const added = [];
  for (const pack of packs) {
    const own = resPaths.filter((resPath) => packFor(packs, resPath) === pack);
    for (const resPath of own) if (!fs.existsSync(toFile(game, resPath))) fail(`${resPath} does not exist.`);
    const before = fs.readFileSync(pack.file, "utf8");
    const listed = listedPaths(before);
    const after = addToPack(before, own, pack.folder);
    if (after !== before) fs.writeFileSync(pack.file, after, "utf8");
    added.push(...own.filter((resPath) => !listed.has(resPath)));
  }
  return [...new Set(added)];
}

module.exports = { addContent, addToPack, contentClasses, gamePacks, listedPaths };

if (require.main === module) {
  main(() => {
    const { values, positionals } = parseToolArgs({
      options: { game: { type: "string" }, missing: { type: "boolean", default: false } },
      allowPositionals: true,
    });
    if (!values.missing && positionals.length === 0) fail("Usage: node tools/add_content.js --game <id> <file>... | --missing");
    const game = resolveGame(values.game);
    const added = addContent({ game, files: positionals, missing: values.missing });
    console.log(added.length === 0 ? "Every file was listed already." : `Listed in the content pack:\n${added.map((resPath) => `  ${resPath}`).join("\n")}`);
  });
}
