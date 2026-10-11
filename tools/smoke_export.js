const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { extractTar, extractZip } = require("./lib/archive");
const { engineErrorLines, fail, main, removeRecursive, run } = require("./lib/common");
const { artifactName, artifactsPath, buildPath, resolveGame } = require("./lib/games");
const { targetsFor } = require("./package_release");

function nativeFor(game) {
  const name = artifactName(game);
  const packages = targetsFor(game);
  return {
    Windows: { executable: `${name}.exe`, build: buildPath(game, "windows"), archive: packages.Windows.output },
    Linux: { executable: `${name}.x86_64`, build: buildPath(game, "linux"), archive: packages.Linux.output },
  };
}

async function smokeNative(game, name, directory) {
  const executable = path.join(directory, nativeFor(game)[name].executable);
  if (!fs.existsSync(executable)) {
    fail(`${name} export not found: ${executable}`);
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
  const native = nativeFor(game);
  for (const name of targets) {
    if (name === "Web") {
      smokeWebPayload(game);
      continue;
    }
    if (!native[name]) {
      fail(`Unknown --target '${name}'. Use Windows, Linux or Web.`);
    }
    if (!fromPackage) {
      await smokeNative(game, name, native[name].build);
      continue;
    }
    const archive = native[name].archive;
    if (!fs.existsSync(archive)) {
      fail(`${name} package not found: ${archive}`);
    }
    const unpacked = artifactsPath(game, "release-smoke", `package-${name.toLowerCase()}`);
    removeRecursive(unpacked);
    if (archive.endsWith(".zip")) {
      extractZip(archive, unpacked);
    } else {
      extractTar(archive, unpacked);
    }
    await smokeNative(game, name, unpacked);
  }
}

module.exports = { smokeExport };

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: {
        game: { type: "string" },
        target: { type: "string", multiple: true },
        "from-package": { type: "boolean", default: false },
      },
    });
    const defaults = process.platform === "win32" ? ["Windows", "Web"] : ["Linux", "Web"];
    await smokeExport({
      game: resolveGame(values.game),
      targets: values.target && values.target.length > 0 ? values.target : defaults,
      fromPackage: values["from-package"],
    });
  });
}
