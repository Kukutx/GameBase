#!/usr/bin/env node
// Creates a new module of the Tiamat foundation:
//
//   node tools/new_module.js --id <id> [--requires <module>[,<module>...]]
//
// It writes tiamat/modules/<id>/ as docs/MODULES.md lays a module out: its
// GameModule class (<id>_module.gd, whose install() wires the module into
// the core), the Simplified Chinese catalog of its text
// (i18n/<id>.zh_CN.po) and a test that it installs itself in every game that
// links it (test/test_<id>_module.gd), and declares it in tiamat/tiamat.json
// with the modules it requires. A game takes it by listing it in its
// game.json; node tools/link.js then links it in.
const fs = require("node:fs");
const path = require("node:path");
const { ROOT, fail, main, parseToolArgs } = require("./lib/common");

// A module's id names its directory and its scripts (npc_social).
const MODULE_ID_RE = /^[a-z][a-z0-9_]*$/;

// The class name of module `id`'s GameModule: npc_social -> NpcSocialModule.
function moduleClass(id) {
  return `${id.split("_").map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join("")}Module`;
}

// `value` as tiamat/tiamat.json is written: two spaces a level, a list of
// plain values on one line.
function formatManifest(value, indent = "") {
  if (Array.isArray(value)) {
    if (value.every((item) => item === null || typeof item !== "object")) return `[${value.map((item) => JSON.stringify(item)).join(", ")}]`;
    return `[\n${value.map((item) => `${indent}  ${formatManifest(item, `${indent}  `)}`).join(",\n")}\n${indent}]`;
  }
  if (value !== null && typeof value === "object") {
    const keys = Object.keys(value);
    if (keys.length === 0) return "{}";
    return `{\n${keys.map((key) => `${indent}  ${JSON.stringify(key)}: ${formatManifest(value[key], `${indent}  `)}`).join(",\n")}\n${indent}}`;
  }
  return JSON.stringify(value);
}

function moduleScript(id) {
  return `class_name ${moduleClass(id)}
extends GameModule

## Wires the ${id} module into the core (see \`GameModule\`; docs/MODULES.md
## lists what a module registers and how it plugs into the modules it
## requires).

func install() -> void:
	pass
`;
}

function moduleTest(id) {
  return `extends GutTest

## The ${id} module wires itself into the core in every game that links it.

func test_the_module_installs_itself() -> void:
	assert_has(GameModules.get_installed(), "${moduleClass(id)}")
`;
}

function moduleCatalog(id) {
  return `msgid ""
msgstr ""
"Project-Id-Version: Tiamat modules/${id}\\n"
"Language: zh_CN\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"Plural-Forms: nplurals=1; plural=0;\\n"
`;
}

// Creates module `id`, which requires `requires`, in the foundation under
// `root` (the repository's, by default), and returns the files it wrote.
function createModule({ id, requires = [], root = ROOT }) {
  if (!MODULE_ID_RE.test(String(id || ""))) fail(`Invalid module id '${id}': use lowercase letters, digits and underscores, starting with a letter.`);
  const manifestFile = path.join(root, "tiamat", "tiamat.json");
  const manifest = JSON.parse(fs.readFileSync(manifestFile, "utf8"));
  const modules = manifest.modules || {};
  const directory = path.join(root, "tiamat", "modules", id);
  if (modules[id] || fs.existsSync(directory)) fail(`Module ${id} already exists.`);
  for (const name of requires) {
    if (!modules[name]) fail(`Module ${id} requires ${name}, which is no module of tiamat/tiamat.json.`);
  }
  const files = {
    [`${id}_module.gd`]: moduleScript(id),
    [path.join("i18n", `${id}.zh_CN.po`)]: moduleCatalog(id),
    [path.join("test", `test_${id}_module.gd`)]: moduleTest(id),
  };
  const written = [];
  for (const [relative, text] of Object.entries(files)) {
    const file = path.join(directory, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, text, "utf8");
    written.push(file);
  }
  // The modules stay in the order of their ids.
  const sorted = {};
  for (const name of [...Object.keys(modules), id].sort()) {
    sorted[name] = name === id ? { requires: [...new Set(requires)].sort() } : modules[name];
  }
  manifest.modules = sorted;
  fs.writeFileSync(manifestFile, `${formatManifest(manifest)}\n`, "utf8");
  return written;
}

module.exports = { createModule, formatManifest, moduleClass };

if (require.main === module) {
  main(() => {
    const { values } = parseToolArgs({ options: { id: { type: "string" }, requires: { type: "string" } } });
    if (!values.id) fail("Usage: node tools/new_module.js --id <id> [--requires <module>[,<module>...]]");
    const requires = (values.requires || "").split(",").map((name) => name.trim()).filter(Boolean);
    createModule({ id: values.id, requires });
    console.log(`Created tiamat/modules/${values.id} (${moduleClass(values.id)}). List it in a game's game.json, run node tools/link.js, then validate that game (its import writes the scripts' .uid files); docs/MODULES.md says what the module can register.`);
  });
}
