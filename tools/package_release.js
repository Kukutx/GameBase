const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { buildZip, buildTar, gzipDeterministic, openZip, readTar } = require("./lib/archive");
const { ROOT, artifactName, fail, git, main, rootPath } = require("./lib/common");

const NAME = artifactName();
const TARGETS = {
  Windows: { source: rootPath("build", "windows"), output: rootPath("dist", `${NAME}-windows-x86_64.zip`), format: "zip" },
  Linux: { source: rootPath("build", "linux"), output: rootPath("dist", `${NAME}-linux-x86_64.tar.gz`), format: "tar.gz" },
  Web: { source: rootPath("build", "web"), output: rootPath("dist", `${NAME}-web.zip`), format: "zip" },
};

function sourceDateEpoch() {
  const value = (process.env.SOURCE_DATE_EPOCH || "").trim();
  if (value) {
    if (!/^-?\d+$/.test(value)) {
      fail("SOURCE_DATE_EPOCH must be an integer");
    }
    return Math.max(0, Number(value));
  }
  return Math.max(0, Number(git(["show", "-s", "--format=%ct", "HEAD"]).trim()));
}

function sourceFiles(source) {
  if (!fs.existsSync(source) || !fs.statSync(source).isDirectory()) {
    fail(`Missing release payload directory: ${source}`);
  }
  const files = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) {
        fail(`Release payload must not contain symlinks: ${absolute}`);
      }
      if (entry.isDirectory()) {
        visit(absolute);
      } else if (entry.isFile()) {
        files.push(path.relative(source, absolute).split(path.sep).join("/"));
      }
    }
  };
  visit(source);
  if (files.length === 0) {
    fail(`Release payload directory is empty: ${source}`);
  }
  // Byte-wise order so the archive does not depend on the host locale.
  return files.sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b)));
}

function canonicalMode(target, relative) {
  return target === "Linux" && relative === `${NAME}.x86_64` ? 0o755 : 0o644;
}

function packageTarget(target, source, output, epoch) {
  const entries = sourceFiles(source).map((relative) => ({
    name: relative,
    data: fs.readFileSync(path.join(source, relative)),
    mode: canonicalMode(target, relative),
  }));
  const archive =
    TARGETS[target].format === "zip" ? buildZip(entries, epoch) : gzipDeterministic(buildTar(entries, epoch), epoch);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, archive);
  if (fs.statSync(output).size <= 0) {
    fail(`Package was not created: ${output}`);
  }
  console.log(`PACKAGED ${target}: ${output} (${archive.length} bytes)`);
}

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function isSorted(names) {
  return names.every((name, index) => index === 0 || Buffer.compare(Buffer.from(names[index - 1]), Buffer.from(name)) <= 0);
}

// Builds each archive format twice from fixtures and requires identical bytes.
function runSelfTest() {
  const epoch = 1_700_000_000;
  const fixtures = {
    Windows: {
      [`${NAME}.exe`]: Buffer.from("windows-binary\0".repeat(100)),
      [`${NAME}.pck`]: Buffer.from("pack-data".repeat(200)),
      "licenses/GODOT_VERSION.txt": Buffer.from("4.7.2\n"),
    },
    Web: {
      "index.html": Buffer.from("<html>GameBase</html>\n"),
      "index.wasm": Buffer.from("wasm".repeat(300)),
      "BUILD_INFO.json": Buffer.from('{"game_version":"0.1.0"}\n'),
    },
    Linux: {
      [`${NAME}.x86_64`]: Buffer.from("linux-binary\0".repeat(100)),
      [`${NAME}.pck`]: Buffer.from("pack-data".repeat(200)),
      "licenses/GODOT_VERSION.txt": Buffer.from("4.7.2\n"),
    },
  };
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "gamebase-package-selftest-"));
  try {
    for (const [target, files] of Object.entries(fixtures)) {
      const source = path.join(temp, target.toLowerCase());
      for (const [relative, data] of Object.entries(files)) {
        const file = path.join(source, relative);
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, data);
      }
      const suffix = target === "Linux" ? ".tar.gz" : ".zip";
      const first = path.join(temp, `${target.toLowerCase()}-1${suffix}`);
      const second = path.join(temp, `${target.toLowerCase()}-2${suffix}`);
      packageTarget(target, source, first, epoch);
      packageTarget(target, source, second, epoch);
      const firstHash = sha256(first);
      if (firstHash !== sha256(second)) {
        fail(`${target} packaging is not reproducible`);
      }

      const expected = Object.keys(files).sort();
      if (target === "Linux") {
        const members = readTar(fs.readFileSync(first));
        const names = members.map((member) => member.name);
        if (!isSorted(names) || names.join("\n") !== expected.join("\n")) {
          fail("Linux archive entries are missing or not sorted");
        }
        const executable = members.find((member) => member.name === `${NAME}.x86_64`);
        if (executable.mode !== 0o755) {
          fail(`Linux executable mode is ${executable.mode.toString(8)}, expected 755`);
        }
        for (const member of members) {
          if (!member.data.equals(files[member.name])) {
            fail(`Linux archive content differs: ${member.name}`);
          }
        }
      } else {
        const zip = openZip(first);
        try {
          const names = zip.entries.map((entry) => entry.name);
          if (!isSorted(names) || names.join("\n") !== expected.join("\n")) {
            fail(`${target} ZIP entries are missing or not sorted`);
          }
          for (const entry of zip.entries) {
            if (!zip.read(entry).equals(files[entry.name])) {
              fail(`${target} ZIP content differs: ${entry.name}`);
            }
          }
        } finally {
          zip.close();
        }
      }
      console.log(`${target}_REPRO_OK=${firstHash}`);
    }
  } finally {
    fs.rmSync(temp, { recursive: true, force: true });
  }
  console.log("DETERMINISTIC_PACKAGING_OK");
  return 0;
}

function cli() {
  const { values } = parseArgs({
    options: {
      target: { type: "string", default: "All" },
      source: { type: "string" },
      output: { type: "string" },
      epoch: { type: "string" },
      "self-test": { type: "boolean", default: false },
    },
  });
  if (values["self-test"]) {
    return runSelfTest();
  }
  if (values.target !== "All" && !TARGETS[values.target]) {
    fail(`Unknown --target '${values.target}'. Use Windows, Linux, Web or All.`);
  }
  if ((values.source === undefined) !== (values.output === undefined)) {
    fail("--source and --output must be provided together");
  }
  if (values.source !== undefined && values.target === "All") {
    fail("--source/--output require one explicit --target");
  }
  if (values.epoch !== undefined && !/^\d+$/.test(values.epoch)) {
    fail("--epoch must be a non-negative integer");
  }
  const epoch = values.epoch !== undefined ? Number(values.epoch) : sourceDateEpoch();
  const targets = values.target === "All" ? Object.keys(TARGETS) : [values.target];
  for (const target of targets) {
    const source = values.source !== undefined ? path.resolve(values.source) : TARGETS[target].source;
    const output = values.output !== undefined ? path.resolve(values.output) : TARGETS[target].output;
    packageTarget(target, source, output, epoch);
  }
  console.log(`SOURCE_DATE_EPOCH=${epoch}`);
  return 0;
}

module.exports = { ROOT, TARGETS, runSelfTest, packageTarget };

if (require.main === module) {
  main(cli);
}
