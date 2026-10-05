const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { fail, git, main, rootPath } = require("./lib/common");

const REPORT_PATH = rootPath("artifacts", "addon-updates.md");
const SEMVER_RE = /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;

const ADDONS = [
  {
    name: "Dialogue Manager",
    plugin: ["addons", "dialogue_manager", "plugin.cfg"],
    repo: "https://github.com/nathanhoad/godot_dialogue_manager.git",
    releaseUrl: "https://github.com/nathanhoad/godot_dialogue_manager/releases",
  },
  {
    name: "GUT",
    plugin: ["addons", "gut", "plugin.cfg"],
    repo: "https://github.com/bitwes/Gut.git",
    releaseUrl: "https://github.com/bitwes/Gut/releases",
  },
];

function parseVersion(raw) {
  const match = SEMVER_RE.exec(raw.trim());
  return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : null;
}

function compareVersions(a, b) {
  return a[0] - b[0] || a[1] - b[1] || a[2] - b[2];
}

function installedVersion(pluginParts) {
  const pluginPath = rootPath(...pluginParts);
  const match = /^version="([^"]+)"$/m.exec(fs.readFileSync(pluginPath, "utf8"));
  if (!match) {
    fail(`Could not read addon version from ${pluginPath}`);
  }
  const version = parseVersion(match[1]);
  if (version === null) {
    fail(`Addon version in ${pluginPath} is not a stable semantic version: ${match[1]}`);
  }
  return version;
}

function latestUpstreamVersion(repo) {
  const versions = [];
  for (const line of git(["ls-remote", "--tags", "--refs", repo], { timeout: 90_000 }).split(/\r?\n/)) {
    const marker = line.lastIndexOf("refs/tags/");
    if (marker < 0) {
      continue;
    }
    const version = parseVersion(line.slice(marker + "refs/tags/".length));
    if (version !== null) {
      versions.push(version);
    }
  }
  if (versions.length === 0) {
    fail(`No stable semantic-version tags found for ${repo}`);
  }
  return versions.sort(compareVersions).at(-1);
}

function buildReport(rows) {
  const updates = rows.filter((row) => row.update_available);
  return [
    "# GameBase addon freshness",
    "",
    "This report is advisory. Addon upgrades remain explicit migrations and must pass the full validation/export suite.",
    "",
    "| Addon | Installed | Latest stable tag | Status |",
    "| --- | ---: | ---: | --- |",
    ...rows.map(
      (row) =>
        `| [${row.name}](${row.release_url}) | ${row.installed} | ${row.latest} | ${row.update_available ? "Update available" : "Current"} |`,
    ),
    "",
    `Updates available: **${updates.length}**`,
    "",
    "For major addon updates, use a clean Git baseline and run clean import, GUT, runtime smoke, the three-year save/load soak, and all release exports before committing.",
    "",
  ].join("\n");
}

function cli() {
  const { values } = parseArgs({
    options: {
      "github-output": { type: "string" },
      json: { type: "boolean", default: false },
      "fail-on-update": { type: "boolean", default: false },
    },
  });

  const rows = ADDONS.map((addon) => {
    const installed = installedVersion(addon.plugin);
    const latest = latestUpstreamVersion(addon.repo);
    return {
      name: addon.name,
      installed: installed.join("."),
      latest: latest.join("."),
      update_available: compareVersions(latest, installed) > 0,
      repo: addon.repo,
      release_url: addon.releaseUrl,
    };
  });
  const updateCount = rows.filter((row) => row.update_available).length;

  const report = buildReport(rows);
  fs.mkdirSync(path.dirname(REPORT_PATH), { recursive: true });
  fs.writeFileSync(REPORT_PATH, report, "utf8");
  process.stdout.write(report);
  console.log(`ADDON_UPDATES_AVAILABLE=${updateCount}`);
  if (values.json) {
    console.log(JSON.stringify(rows, null, 2));
  }

  const outputPath = values["github-output"] || process.env.GITHUB_OUTPUT;
  if (outputPath) {
    fs.appendFileSync(outputPath, `updates_available=${updateCount > 0}\nupdate_count=${updateCount}\n`, "utf8");
  }
  return values["fail-on-update"] && updateCount > 0 ? 2 : 0;
}

if (require.main === module) {
  main(cli);
}
