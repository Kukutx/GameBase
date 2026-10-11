const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { fail, main, rootPath } = require("./lib/common");
const { gamePath, projectSetting, readFoundation, resolveGames } = require("./lib/games");

// Player-visible text is translated in the layer that owns it: the core and
// each module ship their own catalogs under <layer>/i18n/<name>.<locale>.po,
// and a game translates only its own text. A game registers the catalogs of
// every layer it uses in locale/translations, and a layer's text may be
// translated only by its own catalogs or those of the layers below it (the
// core, and the modules a module requires, directly or not). An entry
// translates text its own layer holds, and text that a layer below holds is
// translated by the lowest such layer, so every game that uses that layer gets
// the translation.
function textLayers(game) {
  const foundation = readFoundation();
  const core = { name: "gamebase/core", root: rootPath("gamebase", "core"), res: "res://gamebase/core/", below: [] };
  const required = (module, seen = new Set()) => {
    for (const name of foundation.modules[module]?.requires || []) {
      if (!seen.has(name)) {
        seen.add(name);
        required(name, seen);
      }
    }
    return seen;
  };
  const modules = game.modules.map((module) => ({
    name: `gamebase/modules/${module}`,
    root: rootPath("gamebase", "modules", module),
    res: `res://gamebase/modules/${module}/`,
    below: [core.name, ...[...required(module)].sort().map((name) => `gamebase/modules/${name}`)],
  }));
  const own = { name: `games/${game.id}`, root: gamePath(game, "game"), res: "res://game/", below: [core.name, ...modules.map((layer) => layer.name)], game: true };
  return [core, ...modules, own];
}

const CATALOG_RE = /^[\w-]+\.([A-Za-z]{2,3}(?:_[A-Za-z0-9]+)?)\.po$/;

// The catalogs a foundation layer ships, by locale.
function shippedCatalogs(layer) {
  const directory = path.join(layer.root, "i18n");
  const catalogs = new Map();
  if (!fs.existsSync(directory)) return catalogs;
  for (const name of fs.readdirSync(directory).sort()) {
    const match = CATALOG_RE.exec(name);
    if (match) catalogs.set(match[1], `${layer.res}i18n/${name}`);
  }
  return catalogs;
}

// The translation catalogs the game registers in project.godot.
function registeredCatalogs(game, layers) {
  const raw = projectSetting(game, "internationalization", "locale/translations") || "";
  const catalogs = [];
  for (const [, res] of raw.matchAll(/"(res:\/\/[^"]+\.po)"/g)) {
    const layer = layers.find((candidate) => res.startsWith(candidate.res));
    const match = CATALOG_RE.exec(path.posix.basename(res));
    if (!layer) fail(`games/${game.id}/project.godot registers ${res}, which belongs to no layer the game uses.`);
    if (!match) fail(`games/${game.id}/project.godot registers ${res}; a catalog is named <name>.<locale>.po.`);
    const file = path.join(layer.root, ...res.slice(layer.res.length).split("/"));
    if (!fs.existsSync(file)) fail(`games/${game.id}/project.godot registers ${res}, which does not exist.`);
    catalogs.push({ res, file, layer: layer.name, locale: match[1] });
  }
  if (catalogs.length === 0) fail(`games/${game.id}/project.godot registers no .po translation in locale/translations.`);
  return catalogs;
}

// Calls whose first argument is player-visible source text, including a toast
// sent through a reference to GameEvents (`events.call("toastf", "...", args)`).
const CALL_RE = /(?:\btr|GameEvents\.toastf?|\bset_prompt)\(|\.call\("toastf?",\s*/g;

// Player-facing fields of data resources.
const DATA_RE = /^(?:display_name|short_name|title|description|subject|body|role|activity) = "((?:[^"\\]|\\.)*)"$/gm;

const SCENE_PROPERTIES = [
  "text",
  "display_name",
  "station_name",
  "idle_text",
  "dialog_text",
  "prompt_text",
  "title",
  "ok_button_text",
  "cancel_button_text",
  "placeholder_text",
  "tooltip_text",
  "pending_text",
  "completed_text",
];
const SCENE_RE = new RegExp(`^(?:${SCENE_PROPERTIES.join("|")}) = "((?:[^"\\\\]|\\\\.)*)"$`, "gm");

// Exported text whose default is shown when a scene or a resource does not set it.
const EXPORT_DEFAULT_RE = new RegExp(
  `^@export var (?:${[...SCENE_PROPERTIES, "description", "role", "activity"].join("|")})\\b[^=\\n]*=\\s*"((?:[^"\\\\]|\\\\.)*)"`,
  "gm",
);

// A literal assigned from code to a property that is translated when it is shown.
const ASSIGNED_TEXT_RE = new RegExp(
  `\\b(?:${SCENE_PROPERTIES.filter((name) => name !== "text" && name !== "title").join("|")}) = "((?:[^"\\\\]|\\\\.)*)"`,
  "g",
);

function decodeString(raw) {
  try {
    return JSON.parse(`"${raw}"`);
  } catch {
    return raw;
  }
}

// Skips directories with a .gdignore, which Godot does not import either.
function walk(directory, extension, files = []) {
  if (!fs.existsSync(directory) || fs.existsSync(path.join(directory, ".gdignore"))) return files;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      walk(absolute, extension, files);
    } else if (entry.name.endsWith(extension)) {
      files.push(absolute);
    }
  }
  return files;
}

function readText(file) {
  return fs.readFileSync(file, "utf8").replace(/^﻿/, "");
}

// Collects every string literal that sits directly in the first argument of a
// translation call, so both branches of `"A" if ok else "B"` are found. Literals
// nested deeper (`tr(String(entry["title"]))`) are data lookups, not source text.
function firstArgumentLiterals(text, start) {
  const literals = [];
  let depth = 0;
  let index = start;
  while (index < text.length) {
    const char = text[index];
    if (char === '"') {
      let end = index + 1;
      while (end < text.length && text[end] !== '"') {
        end += text[end] === "\\" ? 2 : 1;
      }
      if (depth === 0) {
        literals.push(text.slice(index + 1, end));
      }
      index = end + 1;
      continue;
    }
    if (char === "(" || char === "[" || char === "{") {
      depth += 1;
    } else if (char === ")" || char === "]" || char === "}") {
      if (depth === 0) {
        break;
      }
      depth -= 1;
    } else if ((char === "," && depth === 0) || char === "\n") {
      break;
    }
    index += 1;
  }
  return literals;
}

function collectDialogueKeys(layer) {
  const keys = new Set();
  for (const file of walk(layer.root, ".dialogue")) {
    for (const rawLine of readText(file).split(/\r?\n/)) {
      const line = rawLine.trim();
      if (!line || line.startsWith("~") || line.startsWith("=>") || line.startsWith("#")) {
        continue;
      }
      if (line.startsWith("- ")) {
        keys.add(line.slice(2).trim());
        continue;
      }
      const match = /^[^:]+:\s*(.+)$/.exec(line);
      if (match) {
        keys.add(match[1].trim());
      }
    }
  }
  return keys;
}

// Every string a layer holds, wherever it sits: the literals of its scripts
// (not StringNames, node paths or comments), the property values of its scenes
// and resources (not resource paths), and its dialogue lines. Text that travels
// as data, such as a season name or a fallback label, is found here although the
// translation calls never name it.
function layerLiterals(layer) {
  const literals = new Set(collectDialogueKeys(layer));
  const add = (raw) => {
    const value = decodeString(raw);
    if (value && !/^(?:res|uid|user):\/\//.test(value)) literals.add(value);
  };
  for (const file of walk(layer.root, ".gd")) {
    for (const line of readText(file).split(/\r?\n/)) {
      let index = 0;
      while (index < line.length && line[index] !== "#") {
        if (line[index] !== '"') {
          index += 1;
          continue;
        }
        let end = index + 1;
        while (end < line.length && line[end] !== '"') end += line[end] === "\\" ? 2 : 1;
        if (index === 0 || (line[index - 1] !== "&" && line[index - 1] !== "^")) add(line.slice(index + 1, end));
        index = end + 1;
      }
    }
  }
  for (const file of [...walk(layer.root, ".tscn"), ...walk(layer.root, ".tres")]) {
    for (const [, value] of readText(file).matchAll(/^[\w/]+ = (.+)$/gm)) {
      for (const [, raw] of value.matchAll(/(?<![&^])"((?:[^"\\]|\\.)*)"/g)) add(raw);
    }
  }
  return literals;
}

// Text the core holds is translated by the core, text a module holds by a
// module, and only the rest by the game.
// The source text a layer shows: translation calls, exported defaults, scene
// text and the player-facing fields of its resources, such as a location's or
// a control's name.
function collectNonDialogueKeys(layer) {
  const keys = new Set();
  const add = (raw) => {
    const value = decodeString(raw);
    if (value) {
      keys.add(value);
    }
  };
  for (const file of walk(layer.root, ".gd")) {
    const text = readText(file);
    for (const match of text.matchAll(CALL_RE)) {
      firstArgumentLiterals(text, match.index + match[0].length).forEach(add);
    }
    for (const match of text.matchAll(EXPORT_DEFAULT_RE)) {
      add(match[1]);
    }
    for (const match of text.matchAll(ASSIGNED_TEXT_RE)) {
      // A layout of already translated parts ("%s\n%s") carries no words of its own.
      if (/\p{L}/u.test(match[1].replace(/%[-+0-9.]*[a-z]|\\[a-z]/g, ""))) {
        add(match[1]);
      }
    }
  }
  for (const file of walk(layer.root, ".tscn")) {
    for (const match of readText(file).matchAll(SCENE_RE)) {
      add(match[1]);
    }
  }
  for (const file of walk(layer.root, ".tres")) {
    for (const match of readText(file).matchAll(DATA_RE)) {
      add(match[1]);
    }
  }
  return keys;
}

function poString(line, prefix) {
  try {
    return JSON.parse(line.slice(prefix.length));
  } catch {
    return undefined;
  }
}

function collectPoEntries(po) {
  const entries = new Map();
  for (const block of fs.readFileSync(po, "utf8").split(/\r?\n\r?\n/)) {
    let context = "";
    let msgid;
    let msgstr;
    for (const rawLine of block.split(/\r?\n/)) {
      const line = rawLine.trim();
      if (line.startsWith("msgctxt ")) {
        context = poString(line, "msgctxt ") ?? context;
      } else if (line.startsWith("msgid ")) {
        msgid = poString(line, "msgid ");
      } else if (line.startsWith("msgstr ")) {
        msgstr = poString(line, "msgstr ");
      }
    }
    if (msgid !== undefined && msgstr !== undefined) {
      entries.set(`${context}\u0000${msgid}`, msgstr);
    }
  }
  return entries;
}

// Every layer's text needs a non-empty entry, for every locale the game
// registers, in a registered catalog of that layer or of a layer below it.
function checkLocalization(game, { reportOnly = false } = {}) {
  const layers = textLayers(game);
  const catalogs = registeredCatalogs(game, layers);
  const locales = [...new Set(catalogs.map((catalog) => catalog.locale))].sort();
  const problems = [];
  const entries = new Map(catalogs.map((catalog) => [catalog, collectPoEntries(catalog.file)]));

  for (const layer of layers.filter((candidate) => !candidate.game)) {
    const shipped = shippedCatalogs(layer);
    for (const [locale, res] of shipped) {
      if (locales.includes(locale) && !catalogs.some((catalog) => catalog.res === res)) {
        problems.push(`games/${game.id}/project.godot must register ${res} in locale/translations`);
      }
    }
  }

  const literals = new Map(layers.map((layer) => [layer.name, layerLiterals(layer)]));
  for (const locale of locales) {
    const inLocale = catalogs.filter((catalog) => catalog.locale === locale);
    const owners = new Map();
    for (const catalog of inLocale) {
      const layer = layers.find((candidate) => candidate.name === catalog.layer);
      for (const key of entries.get(catalog).keys()) {
        if (key === "\u0000") continue; // the header
        const text = key.slice(key.indexOf("\u0000") + 1);
        if (owners.has(key)) problems.push(`${catalog.res} repeats "${text}", which ${owners.get(key)} already translates`);
        else owners.set(key, catalog.res);
        const holders = layer.below
          .map((name) => layers.find((candidate) => candidate.name === name))
          .filter((candidate) => candidate && literals.get(candidate.name).has(text));
        const lowest = holders.filter((candidate) => !holders.some((other) => candidate.below.includes(other.name)));
        if (lowest.length > 0) problems.push(`${catalog.res} translates "${text}" of ${lowest.map((candidate) => candidate.name).join(" or ")}: move it to that layer's catalog`);
        else if (!literals.get(layer.name).has(text)) problems.push(`${catalog.res} translates "${text}", which no text of ${layer.name} holds`);
      }
    }
    let total = 0;
    for (const layer of layers) {
      const visible = new Set([layer.name, ...layer.below]);
      const available = inLocale.filter((catalog) => visible.has(catalog.layer)).map((catalog) => entries.get(catalog));
      const translated = (key) => available.some((catalog) => catalog.get(key));
      const keys = [
        ...[...collectNonDialogueKeys(layer)].map((key) => [`\u0000${key}`, key]),
        ...[...collectDialogueKeys(layer)].map((key) => [`dialogue\u0000${key}`, `[dialogue] ${key}`]),
      ];
      total += keys.length;
      const missing = keys.filter(([key]) => !translated(key)).map(([, label]) => label).sort();
      for (const label of missing) problems.push(`${layer.name} (${locale}): missing ${label}`);
    }
    console.log(`${game.id} ${locale}: LOCALIZATION_SOURCE_KEYS=${total} in ${layers.length} layers, ${inLocale.length} catalogs`);
  }

  for (const problem of problems) console.log(`LOCALIZATION_PROBLEM: ${problem}`);
  console.log(`${game.id}: LOCALIZATION_PROBLEMS=${problems.length}`);
  return problems.length > 0 && !reportOnly ? 1 : 0;
}

module.exports = { checkLocalization, collectDialogueKeys, collectNonDialogueKeys, collectPoEntries, layerLiterals, textLayers };

if (require.main === module) {
  main(() => {
    const { values } = parseArgs({
      options: { game: { type: "string", multiple: true }, "report-only": { type: "boolean", default: false } },
    });
    let failed = 0;
    for (const game of resolveGames(values.game || [])) {
      console.log(`== ${game.id}`);
      failed += checkLocalization(game, { reportOnly: values["report-only"] });
    }
    return failed > 0 ? 1 : 0;
  });
}
