// The single local validation entry point:
//
//   node tools/validate.js [--game <id>]... [--no-repository] [--no-games]
//                          [--godot-bin <godot>] [--clean-import] [--skip-import] [--skip-soak]
//
// Repository steps run once: agent rules, layer dependencies, each game's
// project settings against the manifests, tool tests, the engine baseline and
// its legal bundle, the release packaging self-test, and a game freshly
// created from the new-game template (the core on its own). Game
// steps run for each selected game, all registered games by default: links,
// version, import, localization, GUT, every runtime script under test/runtime/
// (the *_soak.gd ones are skipped by --skip-soak) and a boot of the main scene.
const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { checkLocalization } = require("./check_localization");
const { runSelfTest } = require("./package_release");
const { runCli: runRulesCheck } = require("./validate_rules");
const { runCli: runLayerCheck } = require("./check_layers");
const { linkGame } = require("./link");
const {
  ENGINE_VERSION_RE,
  fail,
  godotVersion,
  importProject,
  main,
  readTrimmed,
  removeRecursive,
  resolveGodotBin,
  rootPath,
  run,
  runGodotStep,
  tempFile,
} = require("./lib/common");
const { gameName, gamePath, gameVersion, listGameIds, loadGame, resolveGames } = require("./lib/games");
const { projectInSync } = require("./lib/project");

function step(title) {
  console.log("");
  console.log(`==> ${title}`);
}

function checkEngine(version) {
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

// The Godot steps of one game project, a registered game or the scaffold check.
async function validateProject(godot, game, { label, skipImport = false, skipSoak = false, cleanImport = false }) {
  const project = game.root;
  if (cleanImport) {
    removeRecursive(path.join(project, ".godot"));
  }
  if (!skipImport) {
    await importProject(godot, project, `${label}: headless import`);
  }
  if (fs.existsSync(path.join(project, ".gutconfig.json"))) {
    await runGodotStep(godot, `${label}: GUT unit tests`, [
      "--headless",
      "--path",
      project,
      "-s",
      "addons/gut/gut_cmdln.gd",
      "-gconfig=.gutconfig.json",
    ]);
  }
  const runtime = path.join(project, "test", "runtime");
  const scripts = fs.existsSync(runtime) ? fs.readdirSync(runtime).filter((name) => name.endsWith(".gd")).sort() : [];
  for (const script of scripts) {
    if (skipSoak && script.endsWith("_soak.gd")) continue;
    await runGodotStep(godot, `${label}: runtime ${script}`, ["--headless", "--path", project, "-s", `test/runtime/${script}`]);
  }
  await runGodotStep(godot, `${label}: main scene boot`, ["--headless", "--path", project, "--quit-after", "120"]);
}

// Creates a game from the new-game template (the core and no module) outside
// games/ and runs every game check on it: the core must work on its own, and a
// new game must pass validation as it is created.
async function validateScaffold(godot) {
  const out = tempFile("gamebase-new-game");
  try {
    const { createGame } = require("./new_game");
    const game = createGame({ id: "scaffold-check", name: "GameBase New Game Check", out });
    await validateGame(godot, game, {});
  } finally {
    removeRecursive(out);
  }
}

async function validateRepository(godot, version) {
  checkEngine(version);

  step("Agent rules and routing");
  if (runRulesCheck(["--strict"]) !== 0) {
    fail("Agent rules check failed.");
  }

  step("Layer dependencies");
  if (runLayerCheck() !== 0) {
    fail("Layer dependency check failed.");
  }

  step("Game project settings");
  const stale = listGameIds().filter((id) => !projectInSync(loadGame(id)));
  if (stale.length > 0) {
    fail(`${stale.map((id) => `games/${id}/project.godot`).join(", ")} does not hold the autoloads, translation catalogs and addon plugins its manifests give. Run node tools/link.js and commit the result.`);
  }
  console.log("Every game's autoloads, catalogs and plugins follow gamebase.json and game.json.");

  step("Tool tests");
  const toolTests = await run(process.execPath, ["--test", "tools/*.test.js"]);
  if (toolTests.code !== 0) {
    fail(`Tool tests failed with exit code ${toolTests.code}`);
  }

  step("Deterministic release packaging self-test");
  runSelfTest();

  await validateScaffold(godot);
}

async function validateGame(godot, game, options) {
  step(`${game.id}: links and version`);
  linkGame(game);
  console.log(`${gameName(game)} ${gameVersion(game)} (games/${game.id})`);

  step(`${game.id}: Simplified Chinese localization coverage`);
  if (checkLocalization(game) !== 0) {
    fail(`${game.id}: localization coverage validation failed.`);
  }

  await validateProject(godot, game, { label: game.id, ...options });
}

async function validate({ godotBin, games = [], repository = true, gameSteps = true, skipImport = false, skipSoak = false, cleanImport = false } = {}) {
  const godot = resolveGodotBin(godotBin);
  const version = godotVersion(godot);
  console.log(`Godot: ${version}`);
  const selected = gameSteps ? resolveGames(games) : [];

  if (repository) {
    await validateRepository(godot, version);
  }
  for (const game of selected) {
    await validateGame(godot, game, { skipImport, skipSoak, cleanImport });
  }

  console.log("");
  const scope = [repository ? "repository" : null, ...selected.map((game) => game.id)].filter(Boolean);
  console.log(`Validation passed: ${scope.join(", ")}.`);
}

module.exports = { validate, validateProject };

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: {
        game: { type: "string", multiple: true },
        "no-repository": { type: "boolean", default: false },
        "no-games": { type: "boolean", default: false },
        "godot-bin": { type: "string" },
        "skip-import": { type: "boolean", default: false },
        "skip-soak": { type: "boolean", default: false },
        "clean-import": { type: "boolean", default: false },
      },
    });
    if (values["no-repository"] && values["no-games"]) {
      fail("--no-repository and --no-games together leave nothing to validate.");
    }
    await validate({
      godotBin: values["godot-bin"],
      games: values.game || [],
      repository: !values["no-repository"],
      gameSteps: !values["no-games"],
      skipImport: values["skip-import"],
      skipSoak: values["skip-soak"],
      cleanImport: values["clean-import"],
    });
  });
}
