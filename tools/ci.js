// Steps used by the GitHub Actions workflows. Each subcommand replaces an
// inline shell block so the workflows contain no logic of their own.
const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { ENGINE_VERSION_RE, fail, git, main, readTrimmed, rootPath, run } = require("./lib/common");
const { distPath, gameName, gameVersion, listGameIds, loadGame, parseReleaseTag, releaseTag, resolveGame } = require("./lib/games");

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

// The games a CI run covers. A push or a manual run covers every game; a pull
// request covers only the games whose own directory it changes, unless it also
// changes anything shared (the foundation, addons, tools, workflows), which
// can affect every game.
function games({ changedFrom }) {
  const all = listGameIds();
  let selected = all;
  if (changedFrom) {
    const changed = git(["diff", "--name-only", changedFrom, "HEAD"]).split(/\r?\n/).filter(Boolean);
    const owners = changed.map((file) => {
      const match = /^games\/([^/]+)\//.exec(file);
      return match && all.includes(match[1]) ? match[1] : null;
    });
    if (changed.length > 0 && owners.every(Boolean)) {
      selected = all.filter((id) => owners.includes(id));
    }
  }
  setOutput("games", JSON.stringify(selected));
  console.log(`Games: ${selected.join(", ")}`);
}

// The game and version a release builds: from a game/<id>/v<version> tag, or
// from --game on a manual run. A tag must equal the version in the game's
// project.godot.
function release({ game: requested }) {
  let game;
  if (process.env.GITHUB_REF_TYPE === "tag") {
    const tag = parseReleaseTag(process.env.GITHUB_REF_NAME);
    if (!tag) {
      fail(`Release tag ${process.env.GITHUB_REF_NAME} must look like game/<id>/v<version>.`);
    }
    game = loadGame(tag.id);
    if (tag.version !== gameVersion(game)) {
      fail(`Release tag ${process.env.GITHUB_REF_NAME} must exactly match ${releaseTag(game, gameVersion(game))}.`);
    }
  } else {
    game = resolveGame(requested);
  }
  const version = gameVersion(game);
  setOutput("game", game.id);
  setOutput("version", version);
  setOutput("tag", releaseTag(game, version));
  console.log(`Releasing ${gameName(game)} ${version} (games/${game.id})`);
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

async function publishRelease({ game: requested }) {
  const tag = parseReleaseTag(process.env.GITHUB_REF_NAME);
  if (!tag || tag.id !== requested) {
    fail(`publish-release runs on a game/${requested}/v<version> tag; got '${process.env.GITHUB_REF_NAME || ""}'.`);
  }
  const game = loadGame(tag.id);
  const dist = distPath(game);
  const assets = fs.existsSync(dist) ? fs.readdirSync(dist).map((name) => path.join(dist, name)) : [];
  if (assets.length === 0) {
    fail(`dist/${game.id}/ contains no release assets.`);
  }
  const title = `${gameName(game)} ${tag.version}`;
  console.log(
    await gh(["release", "create", process.env.GITHUB_REF_NAME, ...assets, "--repo", process.env.GITHUB_REPOSITORY, "--title", title, "--generate-notes", "--verify-tag"]),
  );
}

const COMMANDS = {
  "engine-version": (values) => engineVersion({ latest: values.latest }),
  games: (values) => games({ changedFrom: values["changed-from"] }),
  release: (values) => release({ game: values.game }),
  "addon-issue": (values) => addonIssue({ updatesAvailable: values["updates-available"] === "true" }),
  "compat-summary": (values) => compatSummary({ baseline: values.baseline, version: values.version }),
  "append-summary": (values) => appendSummary(fs.readFileSync(path.resolve(values.file), "utf8")),
  "publish-release": (values) => publishRelease({ game: values.game }),
};

if (require.main === module) {
  main(async () => {
    const { values, positionals } = parseArgs({
      allowPositionals: true,
      options: {
        latest: { type: "boolean", default: false },
        game: { type: "string" },
        "changed-from": { type: "string" },
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
