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
  return output.split(/\r?\n/).filter((line) => ENGINE_ERROR_RE.test(line));
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
    child.on("close", (code) => {
      resolve({ code: code === null ? 1 : code, output: Buffer.concat(chunks).toString("utf8") });
    });
  });
}

async function runGodotStep(godotBin, name, args, options = {}) {
  console.log("");
  console.log(`==> ${name}`);
  const result = await run(godotBin, args, options);
  if (result.code !== 0) {
    fail(`${name} failed with exit code ${result.code}`);
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
  const project = tempFile("gamebase-editor-settings");
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
// launching the editor and quitting does not.
async function importProject(godotBin, project, label) {
  if (!fs.existsSync(path.join(project, ".godot"))) {
    await prepareEditorSettings(godotBin);
  }
  await runGodotStep(godotBin, label, ["--headless", "--path", project, "--import"]);
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
