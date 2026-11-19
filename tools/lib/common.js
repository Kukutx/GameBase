const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..", "..");
const GAME_VERSION_RE = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:\.[0-9A-Za-z-]+)*)?$/;
const ENGINE_VERSION_RE = /^4\.\d+\.\d+$/;
// Godot exits with code 0 after parse errors, missing autoloads and push_error(),
// so every Godot step is also judged by these line prefixes.
const ENGINE_ERROR_RE = /^(?:ERROR|SCRIPT ERROR):/i;
// The editor plugins of GUT and Dialogue Manager ask api.github.com for their
// newest version when the editor opens a project. The repository follows its
// addons' releases itself (tools/check_addon_updates.js) and updates them only
// through that tool, and the request fails on a shared CI address over
// GitHub's rate limit or with a TLS error that names no request, so before
// each Godot step the project's addons are told not to ask
// (quietAddonUpdateChecks()). Should GUT's check run anyway, its own line says
// nothing about the project, so it is reported and does not fail the step.
const UPDATE_CHECK_RE = /^ERROR: \[GUT\] (?:Could not get version info|An error occurred requesting version data)/;
// How long a mark lasts; GUT checks again after a day.
const GUT_CHECK_FRESH_SECONDS = 12 * 60 * 60;

class ToolError extends Error {}

function fail(message) {
  throw new ToolError(message);
}

function rootPath(...parts) {
  return path.join(ROOT, ...parts);
}

function readTrimmed(relative) {
  const absolute = rootPath(relative);
  if (!fs.existsSync(absolute)) {
    fail(`Missing ${relative}.`);
  }
  return fs.readFileSync(absolute, "utf8").replace(/^﻿/, "").trim();
}

function writeText(absolute, text) {
  fs.mkdirSync(path.dirname(absolute), { recursive: true });
  fs.writeFileSync(absolute, text, "utf8");
}

function resolveGodotBin(value) {
  const candidate = value || process.env.GODOT_BIN || "godot";
  return fs.existsSync(candidate) ? path.resolve(candidate) : candidate;
}

function engineErrorLines(output) {
  return output.split(/\r?\n/).filter((line) => ENGINE_ERROR_RE.test(line) && !UPDATE_CHECK_RE.test(line));
}

function updateCheckLines(output) {
  return output.split(/\r?\n/).filter((line) => UPDATE_CHECK_RE.test(line));
}

// Runs a command, mirrors its output live and returns the exit code with the
// combined stdout/stderr text.
function run(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd || ROOT,
      env: options.env || process.env,
      shell: options.shell || false,
      stdio: ["ignore", "pipe", "pipe"],
      windowsHide: true,
    });
    const chunks = [];
    const collect = (stream) => (chunk) => {
      chunks.push(chunk);
      if (!options.quiet) {
        stream.write(chunk);
      }
    };
    child.stdout.on("data", collect(process.stdout));
    child.stderr.on("data", collect(process.stderr));
    child.on("error", (error) => {
      reject(new ToolError(`Could not run '${command}': ${error.message}`));
    });
    // A process a signal stopped (a crash, the out-of-memory killer) has no
    // exit code: it reads as 1, and `signal` names the signal.
    child.on("close", (code, signal) => {
      resolve({ code: code === null ? 1 : code, signal: signal || null, output: Buffer.concat(chunks).toString("utf8") });
    });
  });
}

// Where Godot keeps user:// of the project named `name` (application/config/name):
// <data>/<godot>/app_userdata/<name>, with the characters a folder name may
// not hold replaced as the engine replaces them.
function godotUserDataDir(name) {
  const safe = name.replace(/[\\/:*?"<>|]/g, "_").trim();
  const home = os.homedir();
  if (process.platform === "win32") return path.join(process.env.APPDATA || path.join(home, "AppData", "Roaming"), "Godot", "app_userdata", safe);
  if (process.platform === "darwin") return path.join(home, "Library", "Application Support", "Godot", "app_userdata", safe);
  return path.join(process.env.XDG_DATA_HOME || path.join(home, ".local", "share"), "godot", "app_userdata", safe);
}

// The user:// folder of the project at `project`, or null for one without a
// name or with a user folder of its own.
function projectUserDir(project) {
  const settings = path.join(project, "project.godot");
  if (!fs.existsSync(settings)) return null;
  const text = fs.readFileSync(settings, "utf8");
  const name = /^config\/name="([^"]*)"$/m.exec(text);
  if (!name || /^config\/use_custom_user_dir=true$/m.test(text)) return null;
  return godotUserDataDir(name[1]);
}

// Tells the editor plugins of the project at `project` not to ask the network
// for their newest version: GUT's check is marked done now, from the versions
// file GUT ships (it asks again a day later), and Dialogue Manager's is turned
// off in its user settings, the rest of which stay. An addon the project does
// not link is left alone, and a failure to write only leaves its check to run.
function quietAddonUpdateChecks(project) {
  const userDir = projectUserDir(project);
  if (!userDir) return;
  markGutChecked(project, userDir);
  try {
    if (!fs.existsSync(path.join(project, "addons", "dialogue_manager", "plugin.cfg"))) return;
    const file = path.join(userDir, "dialogue_manager_user_config.json");
    const config = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {};
    if (config && config.check_for_updates === false) return;
    fs.mkdirSync(userDir, { recursive: true });
    fs.writeFileSync(file, JSON.stringify({ ...(config || {}), check_for_updates: false }), "utf8");
  } catch {
    // The check runs.
  }
}

function markGutChecked(project, userDir) {
  try {
    const local = path.join(project, "addons", "gut", "versions.json");
    if (!fs.existsSync(local)) return;
    const file = path.join(userDir, "gut_temp_directory", "versions.json");
    const now = Math.floor(Date.now() / 1000);
    if (fs.existsSync(file)) {
      const cached = JSON.parse(fs.readFileSync(file, "utf8"));
      if (cached && now - Number(cached.fetch_timestamp || 0) < GUT_CHECK_FRESH_SECONDS) return;
    }
    const data = JSON.parse(fs.readFileSync(local, "utf8"));
    data.fetch_timestamp = now;
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(data), "utf8");
  } catch {
    // The check runs, and its line is reported, not failed.
  }
}

// Runs Godot with `args` as the step `name`, failing on a non-zero exit or an
// engine error line. With `options.retryAfterSignal`, a run a signal stopped
// (the engine crashed or was killed, often as it quit) runs once more: for a
// step that is safe to repeat, such as an import, whose work stays on disk.
async function runGodotStep(godotBin, name, args, options = {}) {
  console.log("");
  console.log(`==> ${name}`);
  const at = args.indexOf("--path");
  if (at >= 0 && args[at + 1]) quietAddonUpdateChecks(path.resolve(options.cwd || ROOT, args[at + 1]));
  let result = await run(godotBin, args, options);
  if (result.signal && options.retryAfterSignal) {
    console.log(`${name}: Godot was stopped by ${result.signal}; running the step once more.`);
    result = await run(godotBin, args, options);
  }
  if (result.signal) {
    fail(`${name} was stopped by ${result.signal}`);
  }
  if (result.code !== 0) {
    fail(`${name} failed with exit code ${result.code}`);
  }
  if (updateCheckLines(result.output).length > 0) {
    console.log(`${name}: GUT's online version check failed; it does not affect the project.`);
  }
  const errors = engineErrorLines(result.output);
  if (errors.length > 0) {
    fail(`${name} emitted ${errors.length} Godot error line(s).`);
  }
  return result;
}

// The first editor launch on a machine writes the editor settings file, and
// editor settings registered late in that launch read back as null until then.
// Vendored editor plugins that read them while the project's first import
// initialises them (Dialogue Manager's theme values) then fail with a script
// error. Launching the editor once on an empty throwaway project writes the
// settings before the real import, without touching the repository.
async function prepareEditorSettings(godotBin) {
  const project = tempFile("tiamat-editor-settings");
  fs.mkdirSync(project, { recursive: true });
  try {
    fs.writeFileSync(path.join(project, "project.godot"), "config_version=5\n", "utf8");
    const result = await run(godotBin, ["--headless", "--editor", "--quit", "--path", project], { quiet: true });
    if (result.code !== 0) {
      fail(`Preparing the Godot editor settings failed with exit code ${result.code}.`);
    }
  } finally {
    removeRecursive(project);
  }
}

// Imports a Godot project headless. A first import also initialises the editor
// plugins, so it is preceded by prepareEditorSettings. The dedicated import mode
// waits for importer and editor-plugin work to settle before exiting, which
// launching the editor and quitting does not. An import a signal stopped runs
// once more: what it imported stays, so the second run finishes the rest.
async function importProject(godotBin, project, label) {
  if (!fs.existsSync(path.join(project, ".godot"))) {
    await prepareEditorSettings(godotBin);
  }
  await runGodotStep(godotBin, label, ["--headless", "--path", project, "--import"], { retryAfterSignal: true });
}

function godotVersion(godotBin) {
  const result = spawnSync(godotBin, ["--version"], { encoding: "utf8", windowsHide: true });
  if (result.error || result.status !== 0) {
    fail(`Could not run Godot executable '${godotBin}'.`);
  }
  return (result.stdout || result.stderr || "").split(/\r?\n/)[0].trim();
}

function git(args, options = {}) {
  const result = spawnSync("git", args, {
    cwd: options.cwd || ROOT,
    encoding: "utf8",
    windowsHide: true,
    timeout: options.timeout,
  });
  if (result.error || result.status !== 0) {
    if (options.optional) {
      return null;
    }
    fail(`git ${args.join(" ")} failed: ${(result.stderr || (result.error && result.error.message) || "").trim()}`);
  }
  return result.stdout;
}

function npmCommand(args, options = {}) {
  // npm is a .cmd shim on Windows and needs a shell to start.
  return run("npm", args, { ...options, shell: process.platform === "win32" });
}

async function download(url, destination) {
  const response = await fetch(url, { redirect: "follow" });
  if (!response.ok || response.body === null) {
    fail(`Download failed (${response.status}): ${url}`);
  }
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  const handle = fs.openSync(destination, "w");
  try {
    for await (const chunk of response.body) {
      fs.writeSync(handle, chunk);
    }
  } finally {
    fs.closeSync(handle);
  }
}

function removeRecursive(target) {
  fs.rmSync(target, { recursive: true, force: true });
}

function tempFile(prefix) {
  return path.join(os.tmpdir(), `${prefix}-${process.pid}-${Date.now()}`);
}

// Entry point wrapper: prints tool errors without a stack trace and sets the exit code.
function main(entry) {
  Promise.resolve()
    .then(entry)
    .then((code) => {
      process.exitCode = typeof code === "number" ? code : 0;
    })
    .catch((error) => {
      if (error instanceof ToolError) {
        console.error(error.message);
      } else {
        console.error(error);
      }
      process.exitCode = 1;
    });
}

module.exports = {
  ROOT,
  GAME_VERSION_RE,
  ENGINE_VERSION_RE,
  ENGINE_ERROR_RE,
  ToolError,
  fail,
  rootPath,
  readTrimmed,
  writeText,
  resolveGodotBin,
  engineErrorLines,
  godotUserDataDir,
  quietAddonUpdateChecks,
  run,
  runGodotStep,
  importProject,
  godotVersion,
  git,
  npmCommand,
  download,
  removeRecursive,
  tempFile,
  main,
};
