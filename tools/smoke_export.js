const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { extractTar, extractZip, openZip } = require("./lib/archive");
const { engineErrorLines, fail, main, removeRecursive, run } = require("./lib/common");
const { artifactName, artifactsPath, buildPath, resolveGame } = require("./lib/games");
const { macBundle, targetsFor } = require("./lib/targets");

// The executable of a native build in the directory that holds it.
function executableIn(game, target, directory) {
  const name = artifactName(game);
  if (target === "Windows") return path.join(directory, `${name}.exe`);
  if (target === "Linux") return path.join(directory, `${name}.x86_64`);
  return macBundle(path.join(directory, `${name}.app`)).executable;
}

// The native target of the machine the smoke runs on.
function hostTarget() {
  return { win32: "Windows", darwin: "macOS" }[process.platform] || "Linux";
}

async function smokeNative(game, name, directory) {
  const executable = executableIn(game, name, directory);
  if (!fs.existsSync(executable)) {
    fail(`${name} export not found: ${executable}`);
  }
  if (name !== hostTarget()) {
    fail(`A ${name} build runs on ${name}; this machine runs ${hostTarget()} builds.`);
  }
  if (process.platform !== "win32") {
    fs.chmodSync(executable, 0o755);
  }
  console.log(`==> ${name} exported-build smoke`);
  const result = await run(executable, ["--headless", "--quit-after", "120"], { cwd: directory });
  const artifacts = artifactsPath(game, "release-smoke");
  fs.mkdirSync(artifacts, { recursive: true });
  fs.writeFileSync(path.join(artifacts, `${name.toLowerCase()}.log`), result.output, "utf8");
  if (result.code !== 0) {
    fail(`${name} exported build exited with code ${result.code}.`);
  }
  const errors = engineErrorLines(result.output);
  if (errors.length > 0) {
    fail(`${name} exported build emitted ${errors.length} runtime error line(s).`);
  }
  console.log(`${name} exported-build smoke passed.`);
}

// The newest apksigner of the Android SDK the environment names, or null.
function findApksigner() {
  const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT;
  const tools = sdk ? path.join(sdk, "build-tools") : null;
  if (!tools || !fs.existsSync(tools)) return null;
  const versions = fs.readdirSync(tools).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
  for (const version of versions) {
    const candidate = path.join(tools, version, "apksigner");
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

// No phone runs in CI: an Android package is checked for what a phone
// needs from it (the manifest, the code, the engine for 64-bit ARM, the
// game's project settings), and its signature with the SDK's apksigner when
// the environment names an SDK.
async function smokeAndroid(game, directory) {
  const apk = path.join(directory, `${artifactName(game)}.apk`);
  if (!fs.existsSync(apk)) {
    fail(`Android export not found: ${apk}`);
  }
  console.log("==> Android package smoke");
  const zip = openZip(apk);
  let names;
  try {
    names = new Set(zip.entries.map((entry) => entry.name));
  } finally {
    zip.close();
  }
  const missing = ["AndroidManifest.xml", "classes.dex", "lib/arm64-v8a/libgodot_android.so", "assets/project.binary"].filter((name) => !names.has(name));
  if (missing.length > 0) {
    fail(`${path.basename(apk)} is missing ${missing.join(", ")}.`);
  }
  const apksigner = findApksigner();
  if (apksigner) {
    const result = await run(apksigner, ["verify", apk], { quiet: true });
    if (result.code !== 0) {
      fail(`apksigner does not accept the signature of ${path.basename(apk)}:\n${result.output}`);
    }
    console.log("Android package signature verified.");
  } else if (process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT) {
    fail("The Android SDK the environment names has no build-tools apksigner to verify the package with.");
  } else {
    console.log("No Android SDK named by ANDROID_HOME: the signature was not verified.");
  }
  console.log("Android package smoke passed.");
}

function smokeWebPayload(game) {
  const webRoot = buildPath(game, "web");
  if (!fs.existsSync(path.join(webRoot, "index.html"))) {
    fail(`Web export not found: ${path.join(webRoot, "index.html")}`);
  }
  const files = fs.readdirSync(webRoot);
  for (const extension of [".js", ".wasm", ".pck"]) {
    if (!files.some((file) => file.endsWith(extension))) {
      fail(`Web export is missing required payload: *${extension}`);
    }
  }
  console.log("Web export payload smoke passed.");
}

// With fromPackage the packaged archive in dist/ is unpacked and run, which is
// what a player downloads; otherwise the build/ directory is run in place.
async function smokeExport({ game, targets, fromPackage = false }) {
  const exports = targetsFor(game);
  for (const name of targets) {
    if (name === "Web") {
      smokeWebPayload(game);
      continue;
    }
    if (!exports[name]) {
      fail(`Unknown --target '${name}'. Use ${Object.keys(exports).join(", ")}.`);
    }
    let directory = path.dirname(exports[name].output);
    if (fromPackage) {
      const archive = exports[name].package;
      if (!fs.existsSync(archive)) {
        fail(`${name} package not found: ${archive}`);
      }
      directory = artifactsPath(game, "release-smoke", `package-${name.toLowerCase()}`);
      removeRecursive(directory);
      if (archive.endsWith(".zip")) {
        extractZip(archive, directory);
      } else {
        extractTar(archive, directory);
      }
    }
    if (name === "Android") {
      await smokeAndroid(game, directory);
    } else {
      await smokeNative(game, name, directory);
    }
  }
}

module.exports = { hostTarget, smokeExport };

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: {
        game: { type: "string" },
        target: { type: "string", multiple: true },
        "from-package": { type: "boolean", default: false },
      },
    });
    const defaults = [hostTarget(), "Web"];
    await smokeExport({
      game: resolveGame(values.game),
      targets: values.target && values.target.length > 0 ? values.target : defaults,
      fromPackage: values["from-package"],
    });
  });
}
