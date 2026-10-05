const fs = require("node:fs");
const { parseArgs } = require("node:util");
const { checkLocalization } = require("./check_localization");
const { runSelfTest } = require("./package_release");
const { runCli: runRulesCheck } = require("./validate_rules");
const {
  ENGINE_VERSION_RE,
  GAME_VERSION_RE,
  ROOT,
  fail,
  godotVersion,
  main,
  readTrimmed,
  removeRecursive,
  resolveGodotBin,
  rootPath,
  run,
  runGodotStep,
} = require("./lib/common");

function checkVersions(version) {
  const gameVersion = readTrimmed(".game-version");
  if (!GAME_VERSION_RE.test(gameVersion)) {
    fail("Missing or invalid .game-version. Expected semantic version such as 0.1.0 or 1.0.0-rc.1.");
  }
  const projectLines = fs.readFileSync(rootPath("project.godot"), "utf8").split(/\r?\n/);
  if (!projectLines.includes(`config/version="${gameVersion}"`)) {
    fail(`project.godot application version does not match .game-version (${gameVersion}). Run tools/update_game_version.js.`);
  }
  console.log(`GameBase: ${gameVersion}`);

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
  if (runRulesCheck(["--strict"]) !== 0) {
    fail("Agent rules check failed.");
  }

  console.log("");
  console.log("==> Tool tests");
  const toolTests = await run(process.execPath, ["--test", "tools/*.test.js"]);
  if (toolTests.code !== 0) {
    fail(`Tool tests failed with exit code ${toolTests.code}`);
  }

  if (!skipImport) {
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
  await runGodotStep(godot, "Runtime integration smoke", [
    "--headless",
    "--path",
    ROOT,
    "-s",
    "test/runtime/world_services_smoke.gd",
  ]);
  if (!skipSoak) {
    await runGodotStep(godot, "Three-year save/load soak", [
      "--headless",
      "--path",
      ROOT,
      "-s",
      "test/runtime/long_horizon_soak.gd",
    ]);
  }
  await runGodotStep(godot, "Main scene boot smoke", ["--headless", "--path", ROOT, "--quit-after", "120"]);

  console.log("");
  console.log("GameBase validation passed.");
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
