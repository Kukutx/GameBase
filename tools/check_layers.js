#!/usr/bin/env node
// Enforces the dependency direction of the foundation:
//   gamebase/core      may not use a module or the game,
//   gamebase/modules/* may not use the game,
// and gamebase/core may not name a content id of the game. A script "uses" a
// layer when it names one of its autoloads or class_names, or a res:// path in
// it. An autoload whose script extends a core class (ContentDB extends
// ContentRegistry) is that core contract, implemented by the game; every method
// called on it must exist in its implementation.
//
// Known violations that predate this check live in tools/layer_baseline.json
// with the reason they remain. A new violation fails; so does a baseline entry
// that no longer occurs, so the baseline only ever shrinks.

const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const BASELINE = path.join(__dirname, "layer_baseline.json");

function walk(dir, extensions, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, extensions, out);
    else if (extensions.some((ext) => entry.name.endsWith(ext))) out.push(full);
  }
  return out;
}

function rel(root, file) {
  return path.relative(root, file).split(path.sep).join("/");
}

function layerOf(file) {
  if (file.startsWith("gamebase/core/")) return "core";
  if (file.startsWith("gamebase/modules/")) return `module:${file.split("/")[2]}`;
  if (file.startsWith("game/")) return "game";
  return "other";
}

// Whether code in layer `from` may depend on layer `to`.
function allowed(from, to) {
  if (to === "other" || from === to) return true;
  if (from === "core") return to === "core";
  if (from.startsWith("module:")) return to === "core" || to.startsWith("module:");
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

function collectSymbols(root) {
  const symbols = new Map(); // name -> { file, layer }
  const classFiles = new Map(); // class_name -> file
  for (const file of walk(path.join(root, "gamebase"), [".gd"]).concat(walk(path.join(root, "game"), [".gd"]))) {
    const match = fs.readFileSync(file, "utf8").match(/^class_name\s+(\w+)/m);
    if (match) {
      const relative = rel(root, file);
      classFiles.set(match[1], relative);
      symbols.set(match[1], { file: relative, layer: layerOf(relative) });
    }
  }
  const contracts = new Map(); // autoload -> { impl, base }
  const project = fs.readFileSync(path.join(root, "project.godot"), "utf8");
  for (const match of project.matchAll(/^(\w+)="\*res:\/\/([^"]+\.gd)"$/gm)) {
    const [, name, file] = match;
    let layer = layerOf(file);
    const source = fs.existsSync(path.join(root, file)) ? fs.readFileSync(path.join(root, file), "utf8") : "";
    const base = (source.match(/^extends\s+(\w+)/m) || [])[1];
    if (layer !== "core" && base && classFiles.has(base) && layerOf(classFiles.get(base)) === "core") {
      contracts.set(name, { impl: file, base: classFiles.get(base) });
      layer = "core";
    }
    symbols.set(name, { file, layer });
  }
  return { symbols, contracts };
}

function collectContentIds(root) {
  const ids = new Set();
  for (const file of walk(path.join(root, "game", "data"), [".tres"])) {
    const match = fs.readFileSync(file, "utf8").match(/^id = &"([^"]+)"$/m);
    if (match) ids.add(match[1]);
  }
  return ids;
}

function findViolations(root = ROOT) {
  const { symbols, contracts } = collectSymbols(root);
  const contentIds = collectContentIds(root);
  const violations = {}; // file -> Set of "symbol" | "path:..." | "literal:..."
  const add = (file, what) => {
    (violations[file] ||= new Set()).add(what);
  };
  const files = walk(path.join(root, "gamebase"), [".gd", ".tscn", ".tres"]);
  for (const file of files) {
    const relative = rel(root, file);
    const from = layerOf(relative);
    const raw = fs.readFileSync(file, "utf8");
    for (const match of raw.matchAll(/res:\/\/([\w./-]+)/g)) {
      if (!allowed(from, layerOf(match[1]))) add(relative, `path:${match[1]}`);
    }
    if (!relative.endsWith(".gd")) continue;
    const source = stripComments(raw);
    for (const word of new Set(source.match(/\b[A-Z]\w*\b/g) || [])) {
      const symbol = symbols.get(word);
      if (symbol && !allowed(from, symbol.layer)) add(relative, word);
    }
    if (from === "core") {
      for (const match of source.matchAll(/&?"([a-z][a-z0-9_]*)"/g)) {
        if (contentIds.has(match[1])) add(relative, `literal:${match[1]}`);
      }
    }
  }
  return { violations, contracts };
}

function definedMethods(root, file, seen = new Set()) {
  if (seen.has(file)) return new Set();
  seen.add(file);
  const source = fs.readFileSync(path.join(root, file), "utf8");
  const methods = new Set([...source.matchAll(/^(?:static\s+)?func\s+(\w+)/gm)].map((m) => m[1]));
  const base = (source.match(/^extends\s+(\w+)/m) || [])[1];
  if (base) {
    const { symbols } = collectSymbols(root);
    const symbol = symbols.get(base);
    if (symbol && symbol.file.endsWith(".gd")) for (const m of definedMethods(root, symbol.file, seen)) methods.add(m);
  }
  return methods;
}

// Every method called on a contract autoload must exist in its implementation.
function findContractGaps(root, contracts) {
  const gaps = [];
  const files = walk(path.join(root, "gamebase"), [".gd"]).concat(walk(path.join(root, "game"), [".gd"]));
  for (const [name, contract] of contracts) {
    const methods = definedMethods(root, contract.impl);
    const pattern = new RegExp(`\\b${name}\\.(\\w+)\\s*\\(`, "g");
    for (const file of files) {
      for (const match of stripComments(fs.readFileSync(file, "utf8")).matchAll(pattern)) {
        if (!methods.has(match[1])) gaps.push(`${rel(root, file)} calls ${name}.${match[1]}(), which ${contract.impl} does not define`);
      }
    }
  }
  return gaps;
}

function checkLayers(root = ROOT, baselinePath = BASELINE) {
  const baseline = fs.existsSync(baselinePath) ? JSON.parse(fs.readFileSync(baselinePath, "utf8")) : { entries: {} };
  const { violations, contracts } = findViolations(root);
  const problems = findContractGaps(root, contracts);
  for (const [file, found] of Object.entries(violations)) {
    const known = new Set((baseline.entries[file] || {}).uses || []);
    for (const what of found) {
      if (!known.has(what)) problems.push(`${file} (${layerOf(file)}) must not use ${what}`);
    }
  }
  for (const [file, entry] of Object.entries(baseline.entries)) {
    for (const what of entry.uses || []) {
      if (!(violations[file] && violations[file].has(what))) {
        problems.push(`tools/layer_baseline.json lists ${file} -> ${what}, which no longer occurs; remove it`);
      }
    }
  }
  return problems;
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

module.exports = { checkLayers, findViolations, layerOf, allowed, stripComments, runCli };

if (require.main === module) {
  process.exitCode = runCli();
}
