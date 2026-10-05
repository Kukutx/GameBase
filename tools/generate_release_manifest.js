const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { openZip, readTar } = require("./lib/archive");
const { fail, git, main, readTrimmed, rootPath } = require("./lib/common");

const EXPECTED_PACKAGES = {
  windows: "GameBase-windows-x86_64.zip",
  linux: "GameBase-linux-x86_64.tar.gz",
  web: "GameBase-web.zip",
};
const REQUIRED_PACKAGE_FILES = [
  "BUILD_INFO.json",
  "THIRD_PARTY_NOTICES.md",
  "licenses/GAMEBASE_LICENSE.txt",
  "licenses/GODOT_LICENSE.txt",
  "licenses/GODOT_COPYRIGHT.txt",
  "licenses/GODOT_VERSION.txt",
  "licenses/DIALOGUE_MANAGER_LICENSE.txt",
];
const TARGET_REQUIRED_FILES = {
  windows: ["GameBase.exe", "GameBase.pck"],
  linux: ["GameBase.x86_64", "GameBase.pck"],
  web: ["index.html", "index.js", "index.wasm", "index.pck"],
};
const EXPECTED_TARGET = { windows: "Windows Desktop", linux: "Linux", web: "Web" };

function sha256(file) {
  const hash = crypto.createHash("sha256");
  const handle = fs.openSync(file, "r");
  const buffer = Buffer.allocUnsafe(1024 * 1024);
  try {
    for (let read = fs.readSync(handle, buffer); read > 0; read = fs.readSync(handle, buffer)) {
      hash.update(buffer.subarray(0, read));
    }
  } finally {
    fs.closeSync(handle);
  }
  return hash.digest("hex");
}

function pluginVersion(relative) {
  const match = /^version="([^"]+)"$/m.exec(fs.readFileSync(rootPath(relative), "utf8"));
  if (!match) {
    fail(`Could not read plugin version from ${relative}`);
  }
  return match[1];
}

function normalizeMember(name) {
  return name.replaceAll("\\", "/").replace(/^(?:\.\/)+/, "").replace(/\/+$/, "");
}

// Returns the member names, the bytes of the required distribution files and the file modes.
function packageMembers(file) {
  const payloads = new Map();
  const modes = new Map();
  const names = new Set();
  if (file.toLowerCase().endsWith(".zip")) {
    const zip = openZip(file);
    try {
      for (const entry of zip.entries) {
        const name = normalizeMember(entry.name);
        names.add(name);
        if (REQUIRED_PACKAGE_FILES.includes(name)) {
          payloads.set(name, zip.read(entry));
        }
      }
    } finally {
      zip.close();
    }
    return { names, payloads, modes };
  }
  if (file.endsWith(".tar.gz")) {
    for (const member of readTar(fs.readFileSync(file))) {
      const name = normalizeMember(member.name);
      names.add(name);
      modes.set(name, member.mode);
      if (REQUIRED_PACKAGE_FILES.includes(name)) {
        payloads.set(name, member.data);
      }
    }
    return { names, payloads, modes };
  }
  return fail(`Unsupported release package format: ${path.basename(file)}`);
}

function validatePackage(target, file, expected) {
  const label = path.basename(file);
  if (!fs.existsSync(file) || fs.statSync(file).size <= 0) {
    fail(`Missing or empty ${target} package: ${file}`);
  }
  const { names, payloads, modes } = packageMembers(file);
  const missing = [...REQUIRED_PACKAGE_FILES, ...TARGET_REQUIRED_FILES[target]].filter((name) => !names.has(name)).sort();
  if (missing.length > 0) {
    fail(`${label} is missing distribution/runtime files: ${missing.join(", ")}`);
  }
  if (target === "linux" && (modes.get("GameBase.x86_64") & 0o111) === 0) {
    fail(`${label} GameBase.x86_64 is not executable (mode ${modes.get("GameBase.x86_64").toString(8)})`);
  }

  let buildInfo;
  try {
    buildInfo = JSON.parse(payloads.get("BUILD_INFO.json").toString("utf8").replace(/^﻿/, ""));
  } catch (error) {
    fail(`${label} has invalid BUILD_INFO.json: ${error.message}`);
  }
  const checks = {
    game_version: expected.gameVersion,
    git_commit: expected.commit,
    target: EXPECTED_TARGET[target],
    legal_bundle_version: expected.legalVersion,
  };
  for (const [field, wanted] of Object.entries(checks)) {
    const actual = String(buildInfo[field] ?? "");
    if (actual !== wanted) {
      fail(`${label} BUILD_INFO ${field}='${actual}', expected '${wanted}'`);
    }
  }
  const actualEngine = String(buildInfo.engine ?? "");
  if (!actualEngine.startsWith(expected.engineVersion)) {
    fail(`${label} BUILD_INFO engine='${actualEngine}', expected '${expected.engineVersion}'`);
  }
  if (buildInfo.dirty !== false) {
    fail(`${label} was built from a dirty source tree`);
  }
  const packagedLegalVersion = payloads.get("licenses/GODOT_VERSION.txt").toString("utf8").replace(/^﻿/, "").trim();
  if (packagedLegalVersion !== expected.legalVersion) {
    fail(`${label} legal marker='${packagedLegalVersion}', expected '${expected.legalVersion}'`);
  }
  return { name: label, target, size_bytes: fs.statSync(file).size, sha256: sha256(file) };
}

function cli() {
  const { values } = parseArgs({
    options: {
      dist: { type: "string", default: rootPath("dist") },
      "game-version": { type: "string" },
      "engine-version": { type: "string" },
      "git-commit": { type: "string" },
      tag: { type: "string", default: "" },
    },
  });
  const dist = path.resolve(values.dist);
  const gameVersion = values["game-version"] || readTrimmed(".game-version");
  const engineVersion = values["engine-version"] || readTrimmed(".godot-version");
  const commit = values["git-commit"] || git(["rev-parse", "HEAD"]).trim();
  const legalVersion = readTrimmed("licenses/GODOT_VERSION.txt");
  if (legalVersion !== engineVersion) {
    fail(`Godot legal bundle ${legalVersion} does not match engine ${engineVersion}`);
  }

  const artifacts = Object.entries(EXPECTED_PACKAGES).map(([target, filename]) =>
    validatePackage(target, path.join(dist, filename), { gameVersion, engineVersion, commit, legalVersion }),
  );
  const manifest = {
    schema: 1,
    game_version: gameVersion,
    tag: values.tag,
    git_commit: commit,
    godot_version: engineVersion,
    godot_legal_bundle_version: legalVersion,
    addons: {
      dialogue_manager: pluginVersion("addons/dialogue_manager/plugin.cfg"),
      gut: pluginVersion("addons/gut/plugin.cfg"),
    },
    artifacts,
  };

  fs.mkdirSync(dist, { recursive: true });
  const manifestPath = path.join(dist, "RELEASE_MANIFEST.json");
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  const checksumPath = path.join(dist, "SHA256SUMS.txt");
  const checksummed = [...artifacts.map((item) => path.join(dist, item.name)), manifestPath];
  fs.writeFileSync(checksumPath, checksummed.map((file) => `${sha256(file)}  ${path.basename(file)}\n`).join(""), "utf8");

  console.log(JSON.stringify(manifest, null, 2));
  console.log(`RELEASE_MANIFEST_OK=${manifestPath}`);
  console.log(`RELEASE_CHECKSUMS_OK=${checksumPath}`);
  return 0;
}

if (require.main === module) {
  main(cli);
}
