const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { main, rootPath } = require("./lib/common");

const GAME = rootPath("game");
// Scripts and scenes with player-visible text: the game and the foundation it runs on.
const SOURCE_ROOTS = [GAME, rootPath("gamebase")];
const PO = rootPath("game", "i18n", "ui.zh_CN.po");

// Calls whose first argument is player-visible source text.
const CALL_RE = /(?:\btr|GameEvents\.toastf?|\bset_prompt)\(/g;

// Player-facing fields of data resources.
const DATA_RE = /^(?:display_name|title|description|subject|body|role|activity) = "((?:[^"\\]|\\.)*)"$/gm;

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

// Skips directories with a .gdignore, which Godot does not import either
// (gamebase/templates holds files for other projects).
function walk(directory, extension, files = []) {
  if (fs.existsSync(path.join(directory, ".gdignore"))) return files;
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

function collectDialogueKeys() {
  const keys = new Set();
  for (const file of walk(GAME, ".dialogue")) {
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

function collectNonDialogueKeys() {
  const keys = new Set();
  const add = (raw) => {
    const value = decodeString(raw);
    if (value) {
      keys.add(value);
    }
  };
  for (const file of SOURCE_ROOTS.flatMap((root) => walk(root, ".gd"))) {
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
  for (const file of SOURCE_ROOTS.flatMap((root) => walk(root, ".tscn"))) {
    for (const match of readText(file).matchAll(SCENE_RE)) {
      add(match[1]);
    }
  }
  for (const file of walk(path.join(GAME, "data"), ".tres")) {
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

function collectPoEntries() {
  const entries = new Map();
  for (const block of fs.readFileSync(PO, "utf8").split(/\r?\n\r?\n/)) {
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

function checkLocalization({ reportOnly = false } = {}) {
  const dialogueKeys = collectDialogueKeys();
  const nonDialogueKeys = collectNonDialogueKeys();
  const entries = collectPoEntries();
  const missingGeneric = [...nonDialogueKeys].filter((key) => !entries.get(`\u0000${key}`)).sort();
  const missingDialogue = [...dialogueKeys].filter((key) => !entries.get(`dialogue\u0000${key}`)).sort();
  const missingCount = missingGeneric.length + missingDialogue.length;

  console.log(`LOCALIZATION_SOURCE_KEYS=${new Set([...nonDialogueKeys, ...dialogueKeys]).size}`);
  console.log(`LOCALIZATION_PO_ENTRIES=${entries.size}`);
  console.log(`LOCALIZATION_DIALOGUE_KEYS=${dialogueKeys.size}`);
  console.log(`LOCALIZATION_MISSING=${missingCount}`);
  console.log(`LOCALIZATION_DIALOGUE_CONTEXT_MISSING=${missingDialogue.length}`);
  for (const key of missingGeneric) {
    console.log(`MISSING: ${key}`);
  }
  for (const key of missingDialogue) {
    console.log(`MISSING_DIALOGUE_CONTEXT: ${key}`);
  }
  return missingCount > 0 && !reportOnly ? 1 : 0;
}

module.exports = { checkLocalization };

if (require.main === module) {
  main(() => {
    const { values } = parseArgs({ options: { "report-only": { type: "boolean", default: false } } });
    return checkLocalization({ reportOnly: values["report-only"] });
  });
}
