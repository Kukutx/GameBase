#!/usr/bin/env node
// Installs a pinned version of the GameBase foundation into a game project.
//
// A game repository does not vendor GameBase by hand or by git submodule. It
// runs this tool against a GameBase checkout, which copies the files listed in
// that checkout's gamebase/gamebase.json into the game and records them in
// gamebase.lock.json: the foundation version, the source commit, and a SHA-256
// of every installed file.
//
//   node tools/gamebase_sync.js install --from ../GameBase [--project .] [--modules all|none|a,b] [--force]
//   node tools/gamebase_sync.js check [--project .]
//
// The core is always installed; gamebase.json lists the optional modules and
// the modules each one requires. --modules picks the game's modules (plus
// everything they require); without it, install keeps the lock's selection,
// and a first install takes all of them.
//
// install replaces the previously installed files, removes the ones the new
// version no longer ships, and refuses (unless --force) when an installed file
// was edited in the game: fix it in GameBase so every game gets the fix.
// check fails when an installed file differs from the lock; a game's CI runs it.

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { parseArgs } = require("node:util");

const LOCK = "gamebase.lock.json";
const MANIFEST = "gamebase/gamebase.json";
const SKIPPED_DIRS = new Set([".godot", ".git", "node_modules"]);

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function toPosix(file) {
  return file.split(path.sep).join("/");
}

function listFiles(root, entry) {
  const absolute = path.join(root, entry);
  if (!fs.existsSync(absolute)) return [];
  if (fs.statSync(absolute).isFile()) return [toPosix(entry)];
  const files = [];
  for (const child of fs.readdirSync(absolute, { withFileTypes: true })) {
    if (child.isDirectory() && SKIPPED_DIRS.has(child.name)) continue;
    const relative = path.join(entry, child.name);
    if (child.isDirectory()) files.push(...listFiles(root, relative));
    else if (child.isFile()) files.push(toPosix(relative));
  }
  return files;
}

function readManifest(source) {
  const file = path.join(source, MANIFEST);
  if (!fs.existsSync(file)) throw new Error(`${source} is not a GameBase checkout: ${MANIFEST} is missing`);
  const manifest = JSON.parse(fs.readFileSync(file, "utf8"));
  if (!/^\d+\.\d+\.\d+(?:-[\w.]+)?$/.test(manifest.version || "")) throw new Error(`${MANIFEST} has an invalid version`);
  if (!Array.isArray(manifest.include) || manifest.include.length === 0) throw new Error(`${MANIFEST} includes nothing`);
  return manifest;
}

// `wanted` plus every module it requires, transitively, sorted.
function resolveModules(manifest, wanted) {
  const known = manifest.modules || {};
  const selected = new Set();
  const visit = (name) => {
    if (selected.has(name)) return;
    if (!known[name]) throw new Error(`unknown GameBase module '${name}'; known: ${Object.keys(known).join(", ") || "none"}`);
    selected.add(name);
    for (const required of known[name].requires || []) visit(required);
  };
  for (const name of wanted) visit(name);
  return [...selected].sort();
}

function parseModules(manifest, value) {
  if (value === "all") return Object.keys(manifest.modules || {});
  if (value === "none" || value === "") return [];
  return value.split(",").map((name) => name.trim()).filter(Boolean);
}

function isExcluded(file, excluded) {
  return excluded.some((entry) => (entry.endsWith("/") ? file.startsWith(entry) : file === entry));
}

function shippedFiles(source, manifest, modules = Object.keys(manifest.modules || {})) {
  const modulesDir = manifest.modules_dir || "gamebase/modules/";
  const unselected = Object.keys(manifest.modules || {})
    .filter((name) => !modules.includes(name))
    .map((name) => `${modulesDir}${name}/`);
  const excluded = (manifest.exclude || []).concat(unselected);
  const files = manifest.include.flatMap((entry) => listFiles(source, entry)).filter((file) => !isExcluded(file, excluded));
  return [...new Set(files)].sort();
}

function sourceCommit(source) {
  try {
    const commit = execFileSync("git", ["-C", source, "rev-parse", "HEAD"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    const dirty = execFileSync("git", ["-C", source, "status", "--porcelain"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    return dirty ? `${commit}-dirty` : commit;
  } catch {
    return "unknown";
  }
}

function readLock(project) {
  const file = path.join(project, LOCK);
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : null;
}

// Installed files whose content no longer matches the lock.
function modifiedFiles(project, lock) {
  if (!lock) return [];
  return Object.entries(lock.files)
    .filter(([file, hash]) => !fs.existsSync(path.join(project, file)) || sha256(path.join(project, file)) !== hash)
    .map(([file]) => file);
}

function install({ from, project, modules, force = false }) {
  const source = path.resolve(from);
  const target = path.resolve(project);
  if (source === target) throw new Error("--from and --project are the same directory");
  const manifest = readManifest(source);
  const previous = readLock(target);
  const modified = modifiedFiles(target, previous);
  if (modified.length > 0 && !force) {
    throw new Error(
      `installed GameBase files were changed in this project; make the change in GameBase or pass --force:\n  ${modified.join("\n  ")}`,
    );
  }
  let wanted = modules;
  if (typeof wanted === "string") wanted = parseModules(manifest, wanted);
  if (wanted === undefined) wanted = previous && previous.modules ? previous.modules : Object.keys(manifest.modules || {});
  const selected = resolveModules(manifest, wanted);
  const files = shippedFiles(source, manifest, selected);
  const shipped = new Set(files);
  const removed = previous ? Object.keys(previous.files).filter((file) => !shipped.has(file)) : [];
  for (const file of removed) fs.rmSync(path.join(target, file), { force: true });
  const hashes = {};
  for (const file of files) {
    const destination = path.join(target, file);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(path.join(source, file), destination);
    hashes[file] = sha256(destination);
  }
  const lock = { name: manifest.name, version: manifest.version, commit: sourceCommit(source), modules: selected, files: hashes };
  fs.writeFileSync(path.join(target, LOCK), `${JSON.stringify(lock, null, 2)}\n`);
  return { version: manifest.version, modules: selected, installed: files.length, removed: removed.length, previous: previous && previous.version };
}

function check({ project }) {
  const lock = readLock(path.resolve(project));
  if (!lock) throw new Error(`${LOCK} is missing; run install first`);
  return { version: lock.version, modified: modifiedFiles(path.resolve(project), lock) };
}

function runCli(argv = process.argv.slice(2)) {
  const { positionals, values } = parseArgs({
    args: argv,
    allowPositionals: true,
    options: {
      from: { type: "string" },
      project: { type: "string", default: "." },
      modules: { type: "string" },
      force: { type: "boolean", default: false },
    },
  });
  try {
    if (positionals[0] === "install") {
      if (!values.from) throw new Error("install needs --from <GameBase checkout>");
      const result = install(values);
      const modules = result.modules.length > 0 ? result.modules.join(", ") : "none";
      console.log(`GameBase ${result.previous ? `${result.previous} -> ` : ""}${result.version} (modules: ${modules}): ${result.installed} files installed, ${result.removed} removed.`);
      return 0;
    }
    if (positionals[0] === "check") {
      const result = check(values);
      if (result.modified.length > 0) {
        console.error(`GameBase ${result.version}: installed files differ from ${LOCK}:\n  ${result.modified.join("\n  ")}`);
        return 1;
      }
      console.log(`GameBase ${result.version}: installed files match ${LOCK}.`);
      return 0;
    }
    throw new Error("usage: gamebase_sync.js install --from <GameBase checkout> [--project <dir>] [--modules all|none|a,b] [--force] | check [--project <dir>]");
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    return 1;
  }
}

module.exports = { install, check, shippedFiles, readManifest, resolveModules, runCli };

if (require.main === module) {
  process.exitCode = runCli();
}
