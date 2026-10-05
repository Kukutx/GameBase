const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { validate } = require("./validate");
const { verifyExportContents } = require("./verify_export_contents");
const {
  ENGINE_VERSION_RE,
  GAME_VERSION_RE,
  ROOT,
  download,
  fail,
  git,
  godotVersion,
  main,
  readTrimmed,
  removeRecursive,
  resolveGodotBin,
  rootPath,
  runGodotStep,
} = require("./lib/common");

const PRESETS = {
  "Windows Desktop": { output: "build/windows/GameBase.exe", pack: "build/windows/GameBase.pck" },
  Linux: { output: "build/linux/GameBase.x86_64", pack: "build/linux/GameBase.pck" },
  Web: { output: "build/web/index.html", pack: "build/web/index.pck" },
};
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

async function exportPresets({ presets, godotBin, skipValidation = false, allowEngineDrift = false }) {
  const godot = resolveGodotBin(godotBin);
  if (!skipValidation) {
    await validate({ godotBin: godot });
  }

  const gameVersion = readTrimmed(".game-version");
  if (!GAME_VERSION_RE.test(gameVersion)) {
    fail(`Invalid .game-version: ${gameVersion}`);
  }
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

  try {
    for (const name of presets) {
      const preset = PRESETS[name];
      const absoluteOutput = rootPath(preset.output);
      const parent = path.dirname(absoluteOutput);
      removeRecursive(parent);
      fs.mkdirSync(parent, { recursive: true });

      await runGodotStep(godot, `Exporting ${name} -> ${preset.output}`, [
        "--headless",
        "--path",
        ROOT,
        "--export-release",
        name,
        preset.output,
      ]);
      if (!fs.existsSync(absoluteOutput)) {
        fail(`Export '${name}' did not create '${preset.output}'.`);
      }
      if (!fs.existsSync(rootPath(preset.pack))) {
        fail(`Export '${name}' did not create expected resource pack '${preset.pack}'.`);
      }
      await verifyExportContents({ pckPath: preset.pack, godotBin: godot });

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
        game_version: gameVersion,
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

module.exports = { PRESETS, exportPresets };

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: {
        preset: { type: "string", multiple: true },
        "godot-bin": { type: "string" },
        "skip-validation": { type: "boolean", default: false },
        "allow-engine-drift": { type: "boolean", default: false },
      },
    });
    const presets = values.preset && values.preset.length > 0 ? values.preset : Object.keys(PRESETS);
    for (const name of presets) {
      if (!PRESETS[name]) {
        fail(`Unknown --preset '${name}'. Use one of: ${Object.keys(PRESETS).join(", ")}.`);
      }
    }
    await exportPresets({
      presets,
      godotBin: values["godot-bin"],
      skipValidation: values["skip-validation"],
      allowEngineDrift: values["allow-engine-drift"],
    });
  });
}
