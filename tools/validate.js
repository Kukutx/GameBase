const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { checkLocalization } = require("./check_localization");
const { runSelfTest } = require("./package_release");
const { runCli: runRulesCheck } = require("./validate_rules");
const { runCli: runLayerCheck } = require("./check_layers");
const { createGame } = require("./new_game");
const {
  ENGINE_VERSION_RE,
  GAME_VERSION_RE,
  ROOT,
  fail,
  godotVersion,
  main,
  prepareEditorSettings,
  readTrimmed,
  removeRecursive,
  resolveGodotBin,
  rootPath,
  run,
  runGodotStep,
  tempFile,
  projectName,
} = require("./lib/common");
const { check: checkFoundation } = require("./gamebase_sync");

// Creates a game with tools/new_game.js (the core and no module), then boots it
// and runs a new game through save and load: the core must work on its own.
async function validateNewGame(godot) {
  const project = tempFile("gamebase-new-game");
  try {
    createGame({ out: project, name: "GameBase New Game Check", from: ROOT });
    fs.mkdirSync(path.join(project, "test"), { recursive: true });
    fs.copyFileSync(rootPath("test", "runtime", "new_game_smoke.gd"), path.join(project, "test", "new_game_smoke.gd"));
    await runGodotStep(godot, "New game scaffold import", ["--headless", "--path", project, "--import"]);
    await runGodotStep(godot, "New game scaffold smoke (core only)", ["--headless", "--path", project, "-s", "test/new_game_smoke.gd"]);
  } finally {
    removeRecursive(project);
  }
}

function checkVersions(version) {
  const gameVersion = readTrimmed(".game-version");
  if (!GAME_VERSION_RE.test(gameVersion)) {
    fail("Missing or invalid .game-version. Expected semantic version such as 0.1.0 or 1.0.0-rc.1.");
  }
  const projectLines = fs.readFileSync(rootPath("project.godot"), "utf8").split(/\r?\n/);
  if (!projectLines.includes(`config/version="${gameVersion}"`)) {
    fail(`project.godot application version does not match .game-version (${gameVersion}). Run tools/update_game_version.js.`);
  }
  console.log(`${projectName()}: ${gameVersion}`);

  if (!version.startsWith("4.")) {
    fail(`GameBase requires Godot 4.x; detected '${version}'.`);
  }
  const baseline = readTrimmed(".godot-version");
  if (!ENGINE_VERSION_RE.test(baseline)) {
    fail("Missing or invalid .godot-version stable 4.x baseline.");
  }
  const legalVersion = readTrimmed("licenses/GODOT_VERSION.txt");
  if (legalVersion !== baseline) {
    fail(`Godot legal bundle version '${legalVersion}' does not match .godot-version '${baseline}'. Run tools/update_engine_baseline.js.`);
  }
  const license = fs.readFileSync(rootPath("licenses", "GODOT_LICENSE.txt"), "utf8");
  if (license.length < 500 || !license.includes("Godot Engine contributors")) {
    fail("licenses/GODOT_LICENSE.txt does not look like the official Godot license.");
  }
  const copyright = fs.readFileSync(rootPath("licenses", "GODOT_COPYRIGHT.txt"), "utf8");
  if (copyright.length < 10000 || !copyright.includes("Exhaustive licensing information")) {
    fail("licenses/GODOT_COPYRIGHT.txt does not look like the official Godot copyright bundle.");
  }
  if (!version.startsWith(baseline)) {
    console.warn(
      `WARNING: Local Godot differs from CI baseline ${baseline}. Newer stable Godot 4.x is allowed, but run the full validation before updating the shared baseline.`,
    );
  }
}

async function validate({ godotBin, skipImport = false, skipSoak = false, cleanImport = false } = {}) {
  const godot = resolveGodotBin(godotBin);
  if (cleanImport && fs.existsSync(rootPath(".godot"))) {
    console.log("Removing generated .godot cache for a clean validation...");
    removeRecursive(rootPath(".godot"));
  }

  const version = godotVersion(godot);
  console.log(`Godot: ${version}`);
  checkVersions(version);

  console.log("");
  console.log("==> Agent rules and routing");
  if (!fs.existsSync(rootPath("AGENTS.md"))) {
    console.log("No AGENTS.md; skipped.");
  } else if (runRulesCheck(["--strict"]) !== 0) {
    fail("Agent rules check failed.");
  }

  // A game installed from GameBase must not edit the installed foundation.
  if (fs.existsSync(rootPath("gamebase.lock.json"))) {
    console.log("");
    console.log("==> GameBase lock");
    const foundation = checkFoundation({ project: ROOT });
    if (foundation.modified.length > 0) {
      fail(`GameBase ${foundation.version} files differ from gamebase.lock.json; change them in GameBase:\n  ${foundation.modified.join("\n  ")}`);
    }
    console.log(`GameBase ${foundation.version}: installed files match gamebase.lock.json.`);
  }

  console.log("");
  console.log("==> Layer dependencies");
  if (runLayerCheck() !== 0) {
    fail("Layer dependency check failed.");
  }

  console.log("");
  console.log("==> Tool tests");
  const toolTests = await run(process.execPath, ["--test", "tools/*.test.js"]);
  if (toolTests.code !== 0) {
    fail(`Tool tests failed with exit code ${toolTests.code}`);
  }

  if (!skipImport) {
    if (!fs.existsSync(rootPath(".godot"))) {
      // A first import also initialises the editor plugins; see prepareEditorSettings.
      await prepareEditorSettings(godot);
    }
    // The dedicated import mode waits for importer and editor-plugin work to
    // settle before exiting, which launching the editor and quitting does not.
    await runGodotStep(godot, "Headless import", ["--headless", "--path", ROOT, "--import"]);
  }

  console.log("");
  console.log("==> Simplified Chinese localization coverage");
  if (checkLocalization() !== 0) {
    fail("Localization coverage validation failed.");
  }

  console.log("");
  console.log("==> Deterministic release packaging self-test");
  runSelfTest();

  await runGodotStep(godot, "GUT unit tests", [
    "--headless",
    "--path",
    ROOT,
    "-s",
    "addons/gut/gut_cmdln.gd",
    "-gconfig=.gutconfig.json",
  ]);
  // The game's own runtime checks, when it has them.
  if (fs.existsSync(rootPath("test", "runtime", "world_services_smoke.gd"))) {
    await runGodotStep(godot, "Runtime integration smoke", [
      "--headless",
      "--path",
      ROOT,
      "-s",
      "test/runtime/world_services_smoke.gd",
    ]);
  }
  if (!skipSoak && fs.existsSync(rootPath("test", "runtime", "long_horizon_soak.gd"))) {
    await runGodotStep(godot, "Three-year save/load soak", [
      "--headless",
      "--path",
      ROOT,
      "-s",
      "test/runtime/long_horizon_soak.gd",
    ]);
  }
  await runGodotStep(godot, "Main scene boot smoke", ["--headless", "--path", ROOT, "--quit-after", "120"]);
  // Only the GameBase repository carries the new-game template.
  if (fs.existsSync(rootPath("gamebase", "templates", "new_game"))) {
    await validateNewGame(godot);
  }

  console.log("");
  console.log(`${projectName()} validation passed.`);
}

module.exports = { validate };

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: {
        "godot-bin": { type: "string" },
        "skip-import": { type: "boolean", default: false },
        "skip-soak": { type: "boolean", default: false },
        "clean-import": { type: "boolean", default: false },
      },
    });
    await validate({
      godotBin: values["godot-bin"],
      skipImport: values["skip-import"],
      skipSoak: values["skip-soak"],
      cleanImport: values["clean-import"],
    });
  });
}
