// The platforms every game exports to, in one place. Each target names the
// export preset that builds it (every game's export_presets.cfg has one per
// target, which tools/link.js completes from the new-game template), the
// directory under build/<game>/ its export fills, what the export writes
// there, the package a release ships and its format. The export, the content
// check, the smoke runs, the packager and the release manifest all read
// their targets here, so a new platform is added once.
const fs = require("node:fs");
const path = require("node:path");
const { fail } = require("./common");
const { artifactName, buildPath, distPath } = require("./games");

// The reverse-domain prefix of every game's application id (the macOS bundle
// identifier and the Android package name): <prefix>.<game id>.
const APPLICATION_ID_PREFIX = "io.github.kukutx";

// The export preset of each target, in the order a full export builds them.
const TARGET_PRESETS = {
  Windows: "Windows Desktop",
  Linux: "Linux",
  macOS: "macOS",
  Android: "Android",
  Web: "Web",
};
const TARGET_NAMES = Object.keys(TARGET_PRESETS);
// The archive each target's release package is.
const PACKAGE_FORMATS = { Windows: "zip", Linux: "tar.gz", macOS: "zip", Android: "zip", Web: "zip" };
const PRESET_NAMES = Object.values(TARGET_PRESETS);

// The targets of a game, by name: { name, preset, dir, output, package }.
// `output` and `package` are absolute paths; `output` is the file (or, for
// macOS, the application bundle) the export writes.
function targetsFor(game) {
  const name = artifactName(game);
  const target = (target, dir, output, packageName) => ({
    name: target,
    preset: TARGET_PRESETS[target],
    dir,
    output: buildPath(game, dir, output),
    package: distPath(game, `${packageName}.${PACKAGE_FORMATS[target]}`),
  });
  return {
    Windows: target("Windows", "windows", `${name}.exe`, `${name}-windows-x86_64`),
    Linux: target("Linux", "linux", `${name}.x86_64`, `${name}-linux-x86_64`),
    macOS: target("macOS", "macos", `${name}.app`, `${name}-macos-universal`),
    Android: target("Android", "android", `${name}.apk`, `${name}-android`),
    Web: target("Web", "web", "index.html", `${name}-web`),
  };
}

// The target an export preset builds, or null for a preset of no target.
function targetOfPreset(presetName) {
  return TARGET_NAMES.find((target) => TARGET_PRESETS[target] === presetName) || null;
}

// The game's application id. A game id is lower case letters, digits and
// hyphens; an Android package name allows no hyphen.
function applicationId(game) {
  return `${APPLICATION_ID_PREFIX}.${game.id.replaceAll("-", "_")}`;
}

// Android's version code from the game's version: major, minor and patch as
// MMmmpp, so every later version has a larger code. A pre-release shares the
// code of its version.
function androidVersionCode(version) {
  const match = /^(\d+)\.(\d+)\.(\d+)/.exec(String(version));
  if (!match) fail(`'${version}' is not a semantic version an Android version code can follow.`);
  const [major, minor, patch] = match.slice(1).map(Number);
  if (minor > 99 || patch > 99) fail(`Version ${version}: an Android version code holds a minor and a patch of at most 99.`);
  return major * 10000 + minor * 100 + patch;
}

// The one file of a directory of the exported macOS bundle.
function onlyFile(directory, extension, label) {
  const files = fs.existsSync(directory)
    ? fs.readdirSync(directory, { withFileTypes: true }).filter((entry) => entry.isFile() && (!extension || entry.name.endsWith(extension)))
    : [];
  if (files.length !== 1) fail(`${label}: expected one ${extension || "file"} in ${directory}, found ${files.length}.`);
  return path.join(directory, files[0].name);
}

// The resource pack and the executable inside an exported macOS bundle,
// which the engine names after the game's config/name.
function macBundle(appPath) {
  return {
    pack: onlyFile(path.join(appPath, "Contents", "Resources"), ".pck", "macOS bundle"),
    executable: onlyFile(path.join(appPath, "Contents", "MacOS"), "", "macOS bundle"),
  };
}

// The file holding an exported target's content: the resource pack beside
// the executable, inside the macOS bundle or beside the Web page, or the
// Android package, whose assets are the pack's files.
function exportedPack(target) {
  if (target.name === "macOS") return macBundle(target.output).pack;
  if (target.name === "Android") return target.output;
  if (target.name === "Web") return path.join(path.dirname(target.output), "index.pck");
  return target.output.replace(/\.[^.\\/]+$/, ".pck");
}

module.exports = { APPLICATION_ID_PREFIX, PACKAGE_FORMATS, PRESET_NAMES, TARGET_NAMES, TARGET_PRESETS, androidVersionCode, applicationId, exportedPack, macBundle, targetOfPreset, targetsFor };
