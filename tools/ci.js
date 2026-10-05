// Steps used by the GitHub Actions workflows. Each subcommand replaces an
// inline shell block so the workflows contain no logic of their own.
const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { ENGINE_VERSION_RE, GAME_VERSION_RE, fail, main, readTrimmed, rootPath, run } = require("./lib/common");

const ADDON_ISSUE_TITLE = "Addon updates available";

function setOutput(name, value) {
  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `${name}=${value}\n`, "utf8");
  }
}

function appendSummary(text) {
  if (process.env.GITHUB_STEP_SUMMARY) {
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, text, "utf8");
  } else {
    process.stdout.write(text);
  }
}

async function latestStableGodot() {
  const headers = { Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" };
  if (process.env.GH_TOKEN) {
    headers.Authorization = `Bearer ${process.env.GH_TOKEN}`;
  }
  const response = await fetch("https://api.github.com/repos/godotengine/godot/releases/latest", { headers });
  if (!response.ok) {
    fail(`Could not query the latest Godot release (${response.status}).`);
  }
  const tag = String((await response.json()).tag_name || "");
  if (!/^4\.\d+\.\d+-stable$/.test(tag)) {
    fail(`Latest Godot release is not a stable 4.x tag: ${tag}`);
  }
  return tag.replace(/-stable$/, "");
}

// Resolves the engine version for a run: the manual override, else the newest
// stable release when --latest is given, else the shared baseline.
async function engineVersion({ latest }) {
  const baseline = readTrimmed(".godot-version");
  let version = (process.env.INPUT_ENGINE_VERSION || "").trim();
  if (!version) {
    version = latest ? await latestStableGodot() : baseline;
  }
  if (!ENGINE_VERSION_RE.test(version)) {
    fail(`Expected a stable Godot 4.x semantic version; got: ${version}`);
  }
  setOutput("version", version);
  setOutput("baseline", baseline);
  console.log(`Using Godot ${version} (shared baseline ${baseline})`);
}

function gameVersion() {
  const version = readTrimmed(".game-version");
  if (!GAME_VERSION_RE.test(version)) {
    fail(`Invalid .game-version: ${version}`);
  }
  const projectLines = fs.readFileSync(rootPath("project.godot"), "utf8").split(/\r?\n/);
  if (!projectLines.includes(`config/version="${version}"`)) {
    fail(`project.godot version does not match .game-version (${version})`);
  }
  verifyTag(version);
  setOutput("version", version);
  console.log(`Using GameBase ${version}`);
}

// A release tag must be exactly "v" plus the committed game version.
function verifyTag(version) {
  if (process.env.GITHUB_REF_TYPE === "tag" && process.env.GITHUB_REF_NAME !== `v${version}`) {
    fail(`Release tag ${process.env.GITHUB_REF_NAME} must exactly match v${version}`);
  }
}

async function gh(args) {
  const result = await run("gh", args, { quiet: true });
  if (result.code !== 0) {
    fail(`gh ${args.join(" ")} failed: ${result.output.trim()}`);
  }
  return result.output;
}

// Keeps a single open maintenance issue in step with the addon report: it is
// created or refreshed while an update exists and closed once nothing is pending.
async function addonIssue({ updatesAvailable }) {
  const issues = JSON.parse(await gh(["issue", "list", "--state", "open", "--limit", "100", "--json", "number,title"]));
  const existing = issues.find((issue) => issue.title === ADDON_ISSUE_TITLE);
  const report = rootPath("artifacts", "addon-updates.md");
  if (updatesAvailable) {
    if (existing) {
      await gh(["issue", "edit", String(existing.number), "--body-file", report]);
    } else {
      await gh(["issue", "create", "--title", ADDON_ISSUE_TITLE, "--body-file", report]);
    }
  } else if (existing) {
    await gh([
      "issue",
      "comment",
      String(existing.number),
      "--body",
      "Installed Dialogue Manager and GUT versions now match the newest stable upstream tags. Closing this maintenance reminder.",
    ]);
    await gh(["issue", "close", String(existing.number), "--reason", "completed"]);
  }
}

function compatSummary({ baseline, version }) {
  const lines = [
    "## Godot compatibility probe",
    "",
    `- Shared baseline: \`${baseline}\``,
    `- Tested stable version: \`${version}\``,
    baseline !== version
      ? "- A newer stable engine is available. Review this run before moving `.godot-version`."
      : "- The shared baseline is already the latest tested stable version.",
    "",
  ];
  appendSummary(lines.join("\n"));
}

async function publishRelease() {
  const tag = process.env.GITHUB_REF_NAME;
  if (!tag) {
    fail("GITHUB_REF_NAME is required to publish a release.");
  }
  const dist = rootPath("dist");
  const assets = fs
    .readdirSync(dist)
    .filter((name) => name !== ".gdignore")
    .map((name) => path.join(dist, name));
  if (assets.length === 0) {
    fail("dist/ contains no release assets.");
  }
  console.log(await gh(["release", "create", tag, ...assets, "--repo", process.env.GITHUB_REPOSITORY, "--generate-notes", "--verify-tag"]));
}

const COMMANDS = {
  "engine-version": (values) => engineVersion({ latest: values.latest }),
  "game-version": () => gameVersion(),
  "verify-tag": (values) => verifyTag(values.expected || readTrimmed(".game-version")),
  "addon-issue": (values) => addonIssue({ updatesAvailable: values["updates-available"] === "true" }),
  "compat-summary": (values) => compatSummary({ baseline: values.baseline, version: values.version }),
  "append-summary": (values) => appendSummary(fs.readFileSync(path.resolve(values.file), "utf8")),
  "publish-release": () => publishRelease(),
};

if (require.main === module) {
  main(async () => {
    const { values, positionals } = parseArgs({
      allowPositionals: true,
      options: {
        latest: { type: "boolean", default: false },
        expected: { type: "string" },
        "updates-available": { type: "string" },
        baseline: { type: "string" },
        version: { type: "string" },
        file: { type: "string" },
      },
    });
    const command = COMMANDS[positionals[0]];
    if (!command) {
      fail(`Usage: node tools/ci.js <${Object.keys(COMMANDS).join("|")}> [options]`);
    }
    await command(values);
  });
}
