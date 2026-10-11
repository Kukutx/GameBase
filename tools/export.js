const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { linkGame } = require("./link");
const { validate } = require("./validate");
const { verifyExportContents } = require("./verify_export_contents");
const {
  ENGINE_VERSION_RE,
  download,
  fail,
  git,
  godotVersion,
  importProject,
  main,
  readTrimmed,
  removeRecursive,
  resolveGodotBin,
  rootPath,
  runGodotStep,
} = require("./lib/common");
const { artifactName, buildPath, gameVersion, resolveGame, resolveGames } = require("./lib/games");

const PRESET_NAMES = ["Windows Desktop", "Linux", "Web"];

// Where each preset of a game exports to: build/<game>/<platform>/.
function presetsFor(game) {
  const name = artifactName(game);
  return {
    "Windows Desktop": { output: buildPath(game, "windows", `${name}.exe`), pack: buildPath(game, "windows", `${name}.pck`) },
    Linux: { output: buildPath(game, "linux", `${name}.x86_64`), pack: buildPath(game, "linux", `${name}.pck`) },
    Web: { output: buildPath(game, "web", "index.html"), pack: buildPath(game, "web", "index.pck") },
  };
}
const LICENSE_FILES = [
  "GODOT_LICENSE.txt",
  "GODOT_COPYRIGHT.txt",
  "DIALOGUE_MANAGER_LICENSE.txt",
  "GAMEBASE_LICENSE.txt",
  "GODOT_VERSION.txt",
];

// A compatibility export with an engine other than the baseline ships the legal
// bundle of the engine that actually built it, fetched from the matching tag.
async function prepareDriftLegalBundle(engineSemVer) {
  const temporaryRoot = rootPath(".dev", `export-legal-${engineSemVer}`);
  removeRecursive(temporaryRoot);
  fs.mkdirSync(temporaryRoot, { recursive: true });
  for (const name of ["GAMEBASE_LICENSE.txt", "DIALOGUE_MANAGER_LICENSE.txt"]) {
    fs.copyFileSync(rootPath("licenses", name), path.join(temporaryRoot, name));
  }
  fs.writeFileSync(path.join(temporaryRoot, "GODOT_VERSION.txt"), `${engineSemVer}\n`, "utf8");
  const tag = `${engineSemVer}-stable`;
  await download(`https://raw.githubusercontent.com/godotengine/godot/${tag}/LICENSE.txt`, path.join(temporaryRoot, "GODOT_LICENSE.txt"));
  await download(`https://raw.githubusercontent.com/godotengine/godot/${tag}/COPYRIGHT.txt`, path.join(temporaryRoot, "GODOT_COPYRIGHT.txt"));
  const license = fs.readFileSync(path.join(temporaryRoot, "GODOT_LICENSE.txt"), "utf8");
  const copyright = fs.readFileSync(path.join(temporaryRoot, "GODOT_COPYRIGHT.txt"), "utf8");
  if (
    license.length < 500 ||
    !license.includes("Godot Engine contributors") ||
    copyright.length < 10000 ||
    !copyright.includes("Exhaustive licensing information")
  ) {
    fail(`Downloaded legal bundle for Godot ${engineSemVer} failed validation.`);
  }
  return temporaryRoot;
}

function gitIdentity() {
  const commit = git(["rev-parse", "HEAD"], { optional: true });
  const status = git(["status", "--porcelain"], { optional: true });
  return {
    commit: commit === null ? "unknown" : commit.trim(),
    dirty: status === null ? true : status.trim().length > 0,
  };
}

async function exportPresets({ game, presets = PRESET_NAMES, godotBin, skipValidation = false, allowEngineDrift = false }) {
  const godot = resolveGodotBin(godotBin);
  if (!skipValidation) {
    await validate({ godotBin: godot, games: [game.id] });
  }
  linkGame(game);
  const version = gameVersion(game);
  const engineVersion = godotVersion(godot);
  const engineMatch = /^(\d+\.\d+\.\d+)/.exec(engineVersion);
  if (!engineMatch) {
    fail(`Could not resolve a stable semantic Godot version from '${engineVersion}'.`);
  }
  const engineSemVer = engineMatch[1];
  const baseline = readTrimmed(".godot-version");
  if (!ENGINE_VERSION_RE.test(baseline)) {
    fail(`Invalid .godot-version: ${baseline}`);
  }
  const repoLegalVersion = readTrimmed("licenses/GODOT_VERSION.txt");
  if (repoLegalVersion !== baseline) {
    fail(`Repository Godot legal bundle ${repoLegalVersion} does not match engine baseline ${baseline}. Run tools/update_engine_baseline.js.`);
  }

  let legalSourceRoot = rootPath("licenses");
  let temporaryLegalRoot = null;
  let legalBundleVersion = repoLegalVersion;
  if (engineSemVer !== baseline) {
    if (!allowEngineDrift) {
      fail(
        `Release export requires Godot ${baseline}; detected ${engineSemVer}. Update the baseline after compatibility validation, or use --allow-engine-drift only for compatibility/test artifacts.`,
      );
    }
    legalBundleVersion = engineSemVer;
    temporaryLegalRoot = await prepareDriftLegalBundle(engineSemVer);
    legalSourceRoot = temporaryLegalRoot;
    console.warn(
      `WARNING: Exporting compatibility artifact with Godot ${engineSemVer} while shared baseline is ${baseline}. The output legal bundle was synchronized temporarily to the actual engine.`,
    );
  }
  const identity = gitIdentity();
  const outputs = presetsFor(game);

  try {
    // Exporting needs an imported project; the import is quick when nothing changed.
    await importProject(godot, game.root, `${game.id}: import`);
    for (const name of presets) {
      const preset = outputs[name];
      const label = path.relative(rootPath(), preset.output).split(path.sep).join("/");
      const parent = path.dirname(preset.output);
      removeRecursive(parent);
      fs.mkdirSync(parent, { recursive: true });

      await runGodotStep(godot, `${game.id}: exporting ${name} -> ${label}`, [
        "--headless",
        "--path",
        game.root,
        "--export-release",
        name,
        preset.output,
      ]);
      if (!fs.existsSync(preset.output)) {
        fail(`Export '${name}' did not create '${label}'.`);
      }
      if (!fs.existsSync(preset.pack)) {
        fail(`Export '${name}' did not create expected resource pack '${preset.pack}'.`);
      }
      await verifyExportContents({ game, pckPath: preset.pack, godotBin: godot });

      // Distribution licenses stay beside the executable or Web payload rather
      // than inside the PCK, which keeps legal documents out of res:// while
      // every packaged artifact still carries its notices.
      const licenseTarget = path.join(parent, "licenses");
      fs.cpSync(legalSourceRoot, licenseTarget, { recursive: true });
      fs.copyFileSync(rootPath("THIRD_PARTY_NOTICES.md"), path.join(parent, "THIRD_PARTY_NOTICES.md"));
      if (!LICENSE_FILES.every((file) => fs.existsSync(path.join(licenseTarget, file)))) {
        fail(`Export '${name}' is missing required distribution license files.`);
      }

      const buildInfo = {
        schema: 1,
        game: game.id,
        game_version: version,
        engine: engineVersion,
        legal_bundle_version: legalBundleVersion,
        git_commit: identity.commit,
        dirty: identity.dirty,
        target: name,
      };
      fs.writeFileSync(path.join(parent, "BUILD_INFO.json"), `${JSON.stringify(buildInfo, null, 2)}\n`, "utf8");
    }
    console.log("");
    console.log("Requested exports completed.");
  } finally {
    if (temporaryLegalRoot !== null) {
      removeRecursive(temporaryLegalRoot);
    }
  }
}

module.exports = { PRESET_NAMES, presetsFor, exportPresets };

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: {
        game: { type: "string" },
        all: { type: "boolean", default: false },
        preset: { type: "string", multiple: true },
        "godot-bin": { type: "string" },
        "skip-validation": { type: "boolean", default: false },
        "allow-engine-drift": { type: "boolean", default: false },
      },
    });
    const presets = values.preset && values.preset.length > 0 ? values.preset : PRESET_NAMES;
    for (const name of presets) {
      if (!PRESET_NAMES.includes(name)) {
        fail(`Unknown --preset '${name}'. Use one of: ${PRESET_NAMES.join(", ")}.`);
      }
    }
    if (values.all && values.game) {
      fail("Use --game <id> or --all, not both.");
    }
    const games = values.all ? resolveGames() : [resolveGame(values.game)];
    for (const game of games) {
      await exportPresets({
        game,
        presets,
        godotBin: values["godot-bin"],
        skipValidation: values["skip-validation"],
        allowEngineDrift: values["allow-engine-drift"],
      });
    }
  });
}
