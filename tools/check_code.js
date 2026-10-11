#!/usr/bin/env node
// Guardrails on the GDScript of the foundation and of every game:
//   - a script stays short enough to read and review: at most MAX_LINES lines,
//     a test at most MAX_TEST_LINES;
//   - nothing the game ships loads a resource from user:// or saves one at
//     runtime: a resource file can carry a script, so a save, a profile or a
//     file someone drops into the player's data folder must never run as code.
//     A path held in a constant or variable counts, wherever the call breaks
//     its lines. Player data is JSON: ConfigFile, str_to_var() and
//     bytes_to_var_with_objects() parse Resource("path") and Object(...)
//     values, which load and build what the text names. Tests, which are not
//     exported, may write fixture scenes;
//   - only InputLockService sets SceneTree.paused: a pause is a lock with a
//     reason, so one menu that closes never unpauses what another holds.

const fs = require("node:fs");
const path = require("node:path");
const { stripComments } = require("./check_layers");

const ROOT = path.resolve(__dirname, "..");
const MAX_LINES = 500;
const MAX_TEST_LINES = 1000;
const PAUSE_OWNER = "gamebase/core/input/input_lock.gd";

// A call that loads a resource from the path it is given.
const RESOURCE_LOAD = /(?:(?<![\w.])(?:preload|load)|\bResourceLoader\.(?:load|load_threaded_request|load_threaded_get))\s*\(/g;
// A name given a user:// path (const SAVES := "user://saves").
const USER_PATH_NAME = /\b(?:const|var)\s+(\w+)\b[^=\n]*:?=[^\n]*(?:["']user:\/\/|OS\.get_user_data_dir\(\))/g;
const USER_PATH = /["']user:\/\/|OS\.get_user_data_dir\(\)/;
const RESOURCE_SAVE = /\bResourceSaver\.save\s*\(/;
const OBJECT_PARSER = /\b(?:ConfigFile|str_to_var|bytes_to_var_with_objects)\b/;
// SceneTree.paused set on any tree: get_tree(), a variable naming one, the
// main loop, set_pause() or set("paused", ...). A clock's own `paused` is not.
const PAUSE_WRITE = [
  /(?:\b\w*tree\w*(?:\(\))?|get_main_loop\(\)|SceneTree\))\.paused\s*=(?!=)/i,
  /\.set_pause\s*\(/,
  /\.set(?:_deferred)?\s*\(\s*&?["']paused["']/,
];

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    // The links tools/link.js creates inside a game point back at the shared copy.
    if (entry.isSymbolicLink()) continue;
    if (entry.isDirectory()) walk(full, out);
    else if (entry.name.endsWith(".gd")) out.push(full);
  }
  return out;
}

// The scripts the guardrails cover: the foundation's and each game's own.
function scriptsOf(root) {
  const files = walk(path.join(root, "gamebase"));
  const games = path.join(root, "games");
  if (fs.existsSync(games)) {
    for (const id of fs.readdirSync(games)) {
      files.push(...walk(path.join(games, id, "game")), ...walk(path.join(games, id, "test")));
    }
  }
  return files.map((file) => path.relative(root, file).split(path.sep).join("/")).sort();
}

function checkScript(file, source) {
  const problems = [];
  const lines = source.split("\n").length - (source.endsWith("\n") ? 1 : 0);
  const isTest = file.includes("/test/");
  const limit = isTest ? MAX_TEST_LINES : MAX_LINES;
  if (lines > limit) {
    problems.push(`${file} has ${lines} lines, more than ${limit}; split it by responsibility`);
  }
  const code = stripComments(source);
  if (!isTest) {
    for (const line of userResourceLoads(code)) problems.push(`${file}:${line} loads a resource from user://; read player data as JSON`);
  }
  code.split("\n").forEach((line, index) => {
    const at = `${file}:${index + 1}`;
    if (!isTest && RESOURCE_SAVE.test(line)) problems.push(`${at} saves a resource at runtime; write player data as JSON`);
    if (!isTest && OBJECT_PARSER.test(line)) problems.push(`${at} parses text that can name resources and objects; read player data as JSON`);
    if (PAUSE_WRITE.some((pattern) => pattern.test(line)) && file !== PAUSE_OWNER) problems.push(`${at} sets SceneTree.paused; take a lock with InputLock.lock(reason, true) instead`);
  });
  return problems;
}

// The lines of `code` where a resource load is given a user:// path: written
// out, or through a name the script gave one.
function userResourceLoads(code) {
  const names = [...code.matchAll(USER_PATH_NAME)].map((match) => match[1]);
  const named = names.length > 0 ? new RegExp(`\\b(?:${names.join("|")})\\b`) : null;
  const lines = [];
  for (const match of code.matchAll(RESOURCE_LOAD)) {
    const argument = balancedArgument(code, match.index + match[0].length);
    if (USER_PATH.test(argument) || (named && named.test(argument))) {
      lines.push(code.slice(0, match.index).split("\n").length);
    }
  }
  return lines;
}

// The text between the parenthesis just before `start` and the one that
// closes it, across lines.
function balancedArgument(code, start) {
  let depth = 1;
  for (let index = start; index < code.length; index += 1) {
    const char = code[index];
    if (char === "(") depth += 1;
    else if (char === ")" && --depth === 0) return code.slice(start, index);
  }
  return code.slice(start);
}

function checkCode(root = ROOT) {
  const problems = [];
  for (const file of scriptsOf(root)) {
    problems.push(...checkScript(file, fs.readFileSync(path.join(root, file), "utf8")));
  }
  return problems;
}

function runCli() {
  const problems = checkCode();
  if (problems.length > 0) {
    for (const problem of problems) console.error(`ERROR: ${problem}`);
    console.error(`Code guardrails failed with ${problems.length} problem(s). See tools/check_code.js.`);
    return 1;
  }
  console.log("Code guardrails OK.");
  return 0;
}

module.exports = { checkCode, checkScript, MAX_LINES, MAX_TEST_LINES, runCli };

if (require.main === module) {
  process.exitCode = runCli();
}
