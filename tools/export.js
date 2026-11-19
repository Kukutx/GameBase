// Exports one game (--game, or every game with --all) for each target preset
// (Windows, Linux, macOS, Android, Web, or the --preset ones) into
// build/<id>/<platform>/. It validates the game first unless
// --skip-validation, refuses an engine other than the baseline in
// .godot-version unless --allow-engine-drift (a test build only), signs the
// Android package, checks what each pack holds and puts the licenses beside
// each build.
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
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
  parseToolArgs,
  readTrimmed,
  removeRecursive,
  resolveGodotBin,
  rootPath,
  run,
  runGodotStep,
  tempFile,
} = require("./lib/common");
const { gameVersion, resolveGame, resolveGames } = require("./lib/games");
const { PRESET_NAMES, exportedPack, targetOfPreset, targetsFor } = require("./lib/targets");
const LICENSE_FILES = [
  "GODOT_LICENSE.txt",
  "GODOT_COPYRIGHT.txt",
  "DIALOGUE_MANAGER_LICENSE.txt",
  "NOTO_SANS_SC_LICENSE.txt",
  "TIAMAT_LICENSE.txt",
  "GODOT_VERSION.txt",
];

// A compatibility export with an engine other than the baseline ships the legal
// bundle of the engine that actually built it, fetched from the matching tag.
async function prepareDriftLegalBundle(engineSemVer) {
  const temporaryRoot = rootPath(".dev", `export-legal-${engineSemVer}`);
  removeRecursive(temporaryRoot);
  fs.mkdirSync(temporaryRoot, { recursive: true });
  for (const name of ["TIAMAT_LICENSE.txt", "DIALOGUE_MANAGER_LICENSE.txt", "NOTO_SANS_SC_LICENSE.txt"]) {
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

// What an Android release export signs with. The release keystore, from the
// secret store, stays the same from release to release: the engine's
// GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER and _PASSWORD, or in CI the
// keystore file itself as TIAMAT_ANDROID_KEYSTORE_BASE64 in place of the
// path. Without one the export makes a throwaway key for this build alone,
// which installs and runs but cannot update an install signed with another.
const ANDROID_KEYSTORE_ENV = ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"];
const ANDROID_KEYSTORE_BASE64_ENV = "TIAMAT_ANDROID_KEYSTORE_BASE64";

async function androidSigning() {
  const directory = tempFile("tiamat-android-key");
  const env = { ...process.env };
  const encoded = (env[ANDROID_KEYSTORE_BASE64_ENV] || "").trim();
  if (encoded !== "") {
    if (env.GODOT_ANDROID_KEYSTORE_RELEASE_PATH) fail(`Set ${ANDROID_KEYSTORE_BASE64_ENV} or GODOT_ANDROID_KEYSTORE_RELEASE_PATH, not both.`);
    fs.mkdirSync(directory, { recursive: true });
    env.GODOT_ANDROID_KEYSTORE_RELEASE_PATH = path.join(directory, "release.keystore");
    fs.writeFileSync(env.GODOT_ANDROID_KEYSTORE_RELEASE_PATH, Buffer.from(encoded, "base64"), { mode: 0o600 });
  }
  const given = ANDROID_KEYSTORE_ENV.filter((name) => (env[name] || "") !== "");
  if (given.length === ANDROID_KEYSTORE_ENV.length) {
    if (!fs.existsSync(env.GODOT_ANDROID_KEYSTORE_RELEASE_PATH)) {
      fail("GODOT_ANDROID_KEYSTORE_RELEASE_PATH names no file.");
    }
    return { signing: "release-keystore", env, cleanup: () => removeRecursive(directory) };
  }
  removeRecursive(directory);
  if (given.length > 0) {
    fail(`An Android release keystore needs all of ${ANDROID_KEYSTORE_ENV.join(", ")} (or ${ANDROID_KEYSTORE_BASE64_ENV} for the path); set none for a throwaway key.`);
  }
  fs.mkdirSync(directory, { recursive: true });
  const keystore = path.join(directory, "throwaway.keystore");
  const password = crypto.randomBytes(18).toString("base64url");
  const keytool = process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME, "bin", process.platform === "win32" ? "keytool.exe" : "keytool") : "keytool";
  // prettier-ignore
  const result = await run(keytool, [
    "-genkeypair", "-noprompt", "-keystore", keystore, "-storetype", "PKCS12", "-storepass", password, "-keypass", password,
    "-alias", "tiamat", "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-dname", "CN=Tiamat throwaway build key",
  ], { quiet: true });
  if (result.code !== 0 || !fs.existsSync(keystore)) {
    removeRecursive(directory);
    fail("Could not make a throwaway Android keystore with keytool; set JAVA_HOME to a JDK 17 or later.");
  }
  console.warn("WARNING: No Android release keystore is set; this APK is signed with a throwaway key made for this build.");
  return {
    signing: "throwaway-key",
    env: {
      ...process.env,
      GODOT_ANDROID_KEYSTORE_RELEASE_PATH: keystore,
      GODOT_ANDROID_KEYSTORE_RELEASE_USER: "tiamat",
      GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD: password,
    },
    cleanup: () => removeRecursive(directory),
  };
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
  const targets = targetsFor(game);

  try {
    // Exporting needs an imported project; the import is quick when nothing changed.
    await importProject(godot, game.root, `${game.id}: import`);
    for (const name of presets) {
      const target = targets[targetOfPreset(name)];
      const label = path.relative(rootPath(), target.output).split(path.sep).join("/");
      const parent = path.dirname(target.output);
      removeRecursive(parent);
      fs.mkdirSync(parent, { recursive: true });

      const signing = target.name === "Android" ? await androidSigning() : null;
      try {
        await runGodotStep(godot, `${game.id}: exporting ${name} -> ${label}`, ["--headless", "--path", game.root, "--export-release", name, target.output], {
          env: signing ? signing.env : process.env,
        });
      } finally {
        if (signing) signing.cleanup();
      }
      if (!fs.existsSync(target.output)) {
        fail(`Export '${name}' did not create '${label}'.`);
      }
      await verifyExportContents({ game, pckPath: exportedPack(target), godotBin: godot });

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
        ...(signing ? { signing: signing.signing } : {}),
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

module.exports = { PRESET_NAMES, exportPresets };

if (require.main === module) {
  main(async () => {
    const { values } = parseToolArgs({
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
