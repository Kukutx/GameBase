#!/usr/bin/env node
// Writes a new content entry of a game and lists it in the game's pack:
//
//   node tools/new_content.js --game <id> --kind <kind> --id <entry id> [--set <field>=<value>]...
//   node tools/new_content.js --game <id> --kinds
//
// A content entry is a resource whose script extends ContentEntry and declares
// its kind (`const KIND := &"achievement"`), from the core, a module the game
// links or the game itself. The tool writes `<id>.tres` of that script (or of
// --class, a script that extends it) beside the game's entries of the same
// script, else in `<kind>s/` of the game's first content pack, or in --dir,
// sets its id and each --set field, and lists it in the pack whose folder
// holds it (tools/add_content.js). A field must be one the script or a script
// it extends exports; a value is written as Godot writes it (`42`, `true`,
// `&"fish_caught"`, `PackedStringArray("a", "b")`), and plain text is quoted
// as the field's type asks (a StringName as &"...", a String as "..."), so
// `--set display_name=Master Angler --set progress_flag=fish_caught` works;
// a typed array or dictionary takes its plain literal
// (`--set 'multipliers={&"attack_damage": 1.25}'`).
// --kinds lists the kinds the game can write, with their scripts.
const fs = require("node:fs");
const path = require("node:path");
const { fail, main, parseToolArgs, rootPath } = require("./lib/common");
const { gamePath, resolveGame } = require("./lib/games");
const { addContent, contentClasses, gamePacks } = require("./add_content");

const ID_RE = /^[a-z][a-z0-9_]*$/;
const KIND_RE = /^const KIND\s*:?=\s*&"([^"]+)"/m;
const CLASS_RE = /^class_name\s+(\w+)/m;
const EXTENDS_RE = /^extends\s+(\w+)/m;
const EXPORT_RE = /^@export(?:_\w+)?(?:\([^)\n]*\))?(?:\s+@\w+(?:\([^)\n]*\))?)*\s+var\s+(\w+)\s*(?::\s*([^=\n]+?))?\s*(?::?=\s*(.+))?$/gm;
// A value written as Godot writes one: a number, a boolean or null, quoted
// text, a StringName or NodePath, an array or a dictionary, or a constructor.
const LITERAL_RE = /^(?:-?\d+(?:\.\d+)?(?:e-?\d+)?|true|false|null|&?"[\s\S]*"|\^"[\s\S]*"|\[[\s\S]*\]|\{[\s\S]*\}|[A-Z]\w*(?:\[[^\]]*\])?\([\s\S]*\))$/;
// A typed array or dictionary field, such as `Dictionary[StringName, float]`.
const TYPED_COLLECTION_RE = /^(?:Array|Dictionary)\[[^\]]+\]$/;

function filesUnder(directory, extension) {
  if (!fs.existsSync(directory)) return [];
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    // Linked folders (a game's tiamat/) are read from the foundation itself.
    if (entry.isDirectory() && !entry.name.startsWith(".")) files.push(...filesUnder(full, extension));
    else if (entry.isFile() && entry.name.endsWith(extension)) files.push(full);
  }
  return files.sort();
}

// The scripts a game can use: the foundation's, under res://tiamat/ where the
// game links them, and the game's own. Each its res:// path, whether the game
// links it, and its text.
function gameScripts(game) {
  const scripts = [];
  const foundation = rootPath("tiamat");
  for (const file of filesUnder(foundation, ".gd")) {
    const relative = path.relative(foundation, file).split(path.sep).join("/");
    if (/(^|\/)test\//.test(relative)) continue;
    const resPath = `res://tiamat/${relative}`;
    scripts.push({ resPath, linked: fs.existsSync(gamePath(game, "tiamat", ...relative.split("/"))), text: fs.readFileSync(file, "utf8") });
  }
  for (const folder of ["game"]) {
    for (const file of filesUnder(gamePath(game, folder), ".gd")) {
      const relative = path.relative(game.root, file).split(path.sep).join("/");
      scripts.push({ resPath: `res://${relative}`, linked: true, text: fs.readFileSync(file, "utf8") });
    }
  }
  return scripts;
}

// The content scripts among `scripts`: class name -> its res:// path, the
// class it extends, the kind it declares (or inherits) and whether the game
// links it.
function contentScripts(scripts) {
  const classes = contentClasses(scripts.map((script) => script.text));
  const found = new Map();
  for (const script of scripts) {
    const name = CLASS_RE.exec(script.text);
    if (!name || !classes.has(name[1]) || name[1] === "ContentEntry") continue;
    const kind = KIND_RE.exec(script.text);
    found.set(name[1], { name: name[1], resPath: script.resPath, parent: EXTENDS_RE.exec(script.text)[1], ownKind: kind ? kind[1] : null, linked: script.linked, text: script.text });
  }
  for (const entry of found.values()) {
    let at = entry;
    while (at && !at.ownKind) at = found.get(at.parent);
    entry.kind = at ? at.ownKind : null;
  }
  return found;
}

// The class that declares `kind`, or null.
function classOfKind(scripts, kind) {
  return [...scripts.values()].find((entry) => entry.ownKind === kind) || null;
}

// The fields `entry` and the classes it extends export: name -> type
// ("StringName", "String", "int", ... or "" when the script leaves it to
// its default, typed from that).
function exportedFields(scripts, entry) {
  const fields = new Map([["id", "StringName"], ["custom_fields", "Dictionary"]]);
  for (let at = entry; at; at = scripts.get(at.parent)) {
    for (const [, name, type, initial] of at.text.matchAll(EXPORT_RE)) {
      if (!fields.has(name)) fields.set(name, (type || "").trim() || typeOfDefault((initial || "").trim()));
    }
  }
  return fields;
}

function typeOfDefault(initial) {
  if (initial.startsWith('&"')) return "StringName";
  if (initial.startsWith('"')) return "String";
  if (/^(true|false)$/.test(initial)) return "bool";
  if (/^-?\d+$/.test(initial)) return "int";
  if (/^-?\d+\.\d+$/.test(initial)) return "float";
  const constructor = /^([A-Z]\w*)\(/.exec(initial);
  return constructor ? constructor[1] : "";
}

// `raw`, a --set value, as Godot writes a value of `type`: text is quoted
// for a String or StringName field, and for a field the script leaves untyped
// unless it is written as a value already.
function formatValue(raw, type, field) {
  if (type === "StringName") return raw.startsWith('&"') ? raw : `&${JSON.stringify(raw)}`;
  if (type === "String") return raw.startsWith('"') ? raw : JSON.stringify(raw);
  // A typed collection's plain literal is written as Godot writes it, typed.
  if (TYPED_COLLECTION_RE.test(type) && /^[[{][\s\S]*[\]}]$/.test(raw)) return `${type}(${raw})`;
  if (LITERAL_RE.test(raw)) return raw;
  if (type === "") return JSON.stringify(raw);
  return fail(`Give ${field} (${type}) as Godot writes it, such as 42, true or PackedStringArray("a").`);
}

// The text of a new entry of `entry`'s script with `values` (field -> Godot
// value, the id first).
function renderEntry(entry, values) {
  const lines = [
    `[gd_resource type="Resource" script_class="${entry.name}" format=3]`,
    "",
    `[ext_resource type="Script" path="${entry.resPath}" id="1_script"]`,
    "",
    "[resource]",
    'script = ExtResource("1_script")',
  ];
  for (const [field, value] of values) lines.push(`${field} = ${value}`);
  return `${lines.join("\n")}\n`;
}

// Where a new entry of class `name` goes: the folder holding most of the
// game's entries of it, else `<kind>s/` of the first pack.
function entryFolder(game, packs, name, kind) {
  const counts = new Map();
  for (const pack of packs) {
    for (const file of filesUnder(path.dirname(pack.file), ".tres")) {
      const header = fs.readFileSync(file, "utf8").split("\n", 1)[0];
      if (header.includes(`script_class="${name}"`)) counts.set(path.dirname(file), (counts.get(path.dirname(file)) || 0) + 1);
    }
  }
  const best = [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))[0];
  if (best) return best[0];
  return path.join(path.dirname(packs[0].file), plural(kind));
}

function plural(word) {
  if (/(s|x|ch|sh)$/.test(word)) return `${word}es`;
  if (/[^aeiou]y$/.test(word)) return `${word.slice(0, -1)}ies`;
  return `${word}s`;
}

function newContent({ game, kind, className, id, sets = [], dir }) {
  if (!ID_RE.test(id || "")) fail("--id must be lowercase letters, digits and _, starting with a letter.");
  const scripts = contentScripts(gameScripts(game));
  let entry = className ? scripts.get(className) : classOfKind(scripts, kind);
  if (!entry) fail(className ? `${className} is no content class.` : `No content class declares kind '${kind}'. List the kinds with --kinds.`);
  if (kind && entry.kind !== kind) fail(`${entry.name} is of kind '${entry.kind}', not '${kind}'.`);
  if (!entry.linked) fail(`${entry.resPath} is in a module games/${game.id} does not use (game.json modules).`);
  const fields = exportedFields(scripts, entry);
  const values = new Map([["id", `&"${id}"`]]);
  for (const set of sets) {
    const at = set.indexOf("=");
    if (at <= 0) fail(`--set ${set}: write <field>=<value>.`);
    const field = set.slice(0, at).trim();
    if (!fields.has(field)) fail(`${entry.name} exports no field '${field}' (it exports ${[...fields.keys()].sort().join(", ")}).`);
    if (field === "id") fail("Give the id with --id.");
    values.set(field, formatValue(set.slice(at + 1), fields.get(field), field));
  }
  const packs = gamePacks(game);
  const folder = dir ? (dir.startsWith("res://") ? gamePath(game, ...dir.slice(6).split("/")) : path.resolve(dir)) : entryFolder(game, packs, entry.name, entry.kind);
  const file = path.join(folder, `${id}.tres`);
  if (fs.existsSync(file)) fail(`${path.relative(rootPath(), file)} exists already.`);
  fs.mkdirSync(folder, { recursive: true });
  fs.writeFileSync(file, renderEntry(entry, values), "utf8");
  addContent({ game, files: [file] });
  return file;
}

// The kinds the game can write: kind -> the class that declares it and its script.
function listKinds(game) {
  const scripts = contentScripts(gameScripts(game));
  return [...scripts.values()].filter((entry) => entry.ownKind && entry.linked).sort((a, b) => a.ownKind.localeCompare(b.ownKind));
}

module.exports = { contentScripts, exportedFields, formatValue, newContent, plural, renderEntry, typeOfDefault };

if (require.main === module) {
  main(() => {
    const { values } = parseToolArgs({
      options: {
        game: { type: "string" },
        kind: { type: "string" },
        class: { type: "string" },
        id: { type: "string" },
        set: { type: "string", multiple: true, default: [] },
        dir: { type: "string" },
        kinds: { type: "boolean", default: false },
      },
    });
    const game = resolveGame(values.game);
    if (values.kinds) {
      for (const entry of listKinds(game)) console.log(`${entry.ownKind.padEnd(20)} ${entry.name.padEnd(24)} ${entry.resPath}`);
      return;
    }
    if (!values.kind && !values.class) fail("Usage: node tools/new_content.js --game <id> --kind <kind> --id <id> [--set <field>=<value>]... | --kinds");
    const file = newContent({ game, kind: values.kind, className: values.class, id: values.id, sets: values.set, dir: values.dir });
    console.log(`Wrote ${path.relative(rootPath(), file)} and listed it in the content pack.`);
    console.log(`Run node tools/validate.js --game ${game.id} to check it.`);
  });
}
