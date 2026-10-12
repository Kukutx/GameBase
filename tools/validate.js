// The single local validation entry point:
//
//   node tools/validate.js [--game <id>]... [--no-repository] [--no-games]
//                          [--godot-bin <godot>] [--clean-import] [--skip-import] [--skip-soak]
//   node tools/validate.js --test <script> [--unit <name>] [--game <id>]... [--skip-import]
//
// Repository steps run once: agent rules, layer dependencies, code guardrails
// (tools/check_code.js), each game's project settings against the manifests,
// the reference pages (tools/generate_reference.js), tool tests, the engine
// baseline and its legal bundle, the release packaging self-test, and a game
// freshly created from the new-game template (the core on its own). Game
// steps run for each selected game, all registered games by default: links,
// version, import, localization, GUT, every runtime script under test/runtime/
// (the *_soak.gd ones are skipped by --skip-soak) and a boot of the main scene.
//
// --test runs one GUT script (test_save_slots, or a res:// path where a
// module and the game both have a script of that name) and nothing else,
// after the links and the import of each selected game that runs it; --unit
// keeps only its tests whose names contain <name>.
const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { checkLocalization } = require("./check_localization");
const { runSelfTest } = require("./package_release");
const { runCli: runRulesCheck } = require("./validate_rules");
const { runCli: runLayerCheck } = require("./check_layers");
const { runCli: runCodeCheck } = require("./check_code");
const { stalePages } = require("./generate_reference");
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
const { gameName, gamePath, gameVersion, listGameIds, loadGame, resolveGames, templateGame } = require("./lib/games");
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

// The GUT scripts in the test directories of `game`'s .gutconfig.json that
// `script` names, as res:// paths: those of that file name (test_mail.gd,
// which a module and a game may both have) or, for a res:// path, that one.
function findTestScripts(game, script) {
  const config = JSON.parse(fs.readFileSync(path.join(game.root, ".gutconfig.json"), "utf8"));
  const roots = (config.dirs || []).map((dir) => (dir.endsWith("/") ? dir : `${dir}/`));
  const onDisk = (res) => path.join(game.root, res.replace(/^res:\/\//, ""));
  if (script.startsWith("res://")) {
    const tested = roots.some((root) => script.startsWith(root) && (config.include_subdirs || !script.slice(root.length).includes("/")));
    return tested && fs.existsSync(onDisk(script)) ? [script] : [];
  }
  const found = [];
  const search = (res) => {
    const directory = onDisk(res);
    if (!fs.existsSync(directory)) return;
    for (const name of fs.readdirSync(directory).sort()) {
      if (name === script) {
        found.push(`${res}${name}`);
      } else if (config.include_subdirs && fs.statSync(path.join(directory, name)).isDirectory()) {
        search(`${res}${name}/`);
      }
    }
  };
  for (const root of roots) search(root);
  return found;
}

// Runs the GUT script `test` (a file name with or without .gd, or a res://
// path) in each of `games` that runs it, `unit` narrowing it to the tests
// whose names contain it. Fails when no game runs the script, when a game
// has more than one of that name, or when a game ran none of its tests.
async function validateTest(godot, games, { test, unit, skipImport }) {
  const script = `${test.replace(/\.gd$/, "")}.gd`;
  const ran = [];
  for (const game of games) {
    step(`${game.id}: links`);
    linkGame(game);
    const found = findTestScripts(game, script);
    if (found.length === 0) {
      console.log(`${game.id} runs no ${script}; skipped.`);
      continue;
    }
    if (found.length > 1) {
      fail(`${game.id} runs ${found.length} scripts named ${script}: ${found.join(", ")}. Name one by its res:// path.`);
    }
    if (!skipImport) {
      await importProject(godot, game.root, `${game.id}: headless import`);
    }
    // An empty -gdir leaves out the directories the config names.
    const args = ["--headless", "--path", game.root, "-s", "addons/gut/gut_cmdln.gd", "-gconfig=.gutconfig.json", "-gdir=", `-gtest=${found[0]}`];
    if (unit) args.push(`-gunit_test_name=${unit}`);
    const result = await runGodotStep(godot, `${game.id}: GUT ${found[0]}${unit ? ` (tests named *${unit}*)` : ""}`, args);
    const count = /^Tests\s+(\d+)\s*$/m.exec(result.output.replace(/\x1b\[[0-9;]*m/g, ""));
    if (!count || Number(count[1]) === 0) {
      fail(`${game.id}: no test of ${found[0]}${unit ? ` named *${unit}*` : ""} ran.`);
    }
    ran.push(game.id);
  }
  if (ran.length === 0) {
    fail(`No selected game runs ${script}.`);
  }
  return ran;
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

  step("Code guardrails");
  if (runCodeCheck() !== 0) {
    fail("Code guardrail check failed.");
  }

  step("Game project settings");
  const stale = listGameIds().filter((id) => !projectInSync(loadGame(id))).map((id) => `games/${id}`);
  if (!projectInSync(templateGame())) stale.push("gamebase/templates/new_game");
  if (stale.length > 0) {
    fail(`${stale.join(", ")}: project.godot or .gutconfig.json does not hold the autoloads, translation catalogs, addon plugins and test directories its manifests give. Run node tools/link.js and commit the result.`);
  }
  console.log("Every game's and the template's autoloads, catalogs and plugins follow gamebase.json and game.json.");

  step("Reference pages");
  const staleReference = stalePages();
  if (staleReference.length > 0) {
    fail(`${staleReference.join(", ")} no longer match the code. Run node tools/generate_reference.js and commit the result.`);
  }
  console.log("docs/reference/ matches the autoloads, signals and rule keys of the code.");

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

async function validate({ godotBin, games = [], repository = true, gameSteps = true, skipImport = false, skipSoak = false, cleanImport = false, test = null, unit = null } = {}) {
  const godot = resolveGodotBin(godotBin);
  const version = godotVersion(godot);
  console.log(`Godot: ${version}`);
  if (test) {
    const ran = await validateTest(godot, resolveGames(games), { test, unit, skipImport });
    console.log("");
    console.log(`${test} passed: ${ran.join(", ")}.`);
    return;
  }
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

module.exports = { findTestScripts, validate, validateProject };

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
        test: { type: "string" },
        unit: { type: "string" },
      },
    });
    if (values["no-repository"] && values["no-games"]) {
      fail("--no-repository and --no-games together leave nothing to validate.");
    }
    if (values.unit && !values.test) {
      fail("--unit names tests of the script --test runs.");
    }
    if (values.test && (values["no-games"] || values["no-repository"] || values["skip-soak"] || values["clean-import"])) {
      fail("--test runs one script of the games' unit tests and takes no other step's switch but --skip-import.");
    }
    await validate({
      godotBin: values["godot-bin"],
      games: values.game || [],
      repository: !values["no-repository"],
      gameSteps: !values["no-games"],
      skipImport: values["skip-import"],
      skipSoak: values["skip-soak"],
      cleanImport: values["clean-import"],
      test: values.test || null,
      unit: values.unit || null,
    });
  });
}
