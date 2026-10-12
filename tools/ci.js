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

// Documentation, which no game reads: the repository checks, which hold the
// documentation's own rules, cover a change to it.
function isDocumentation(file) {
  return file.endsWith(".md") || file.startsWith("docs/");
}

// The games a CI run covers. A push or a manual run covers every game; a pull
// request covers only the games whose own directory it changes, unless it also
// changes anything shared (the foundation, addons, tools, workflows), which
// can affect every game, and none when it changes documentation alone.
function selectGames(all, changed) {
  const code = changed.filter((file) => !isDocumentation(file));
  if (changed.length > 0 && code.length === 0) return [];
  const owners = code.map((file) => {
    const match = /^games\/([^/]+)\//.exec(file);
    return match && all.includes(match[1]) ? match[1] : null;
  });
  return code.length > 0 && owners.every(Boolean) ? all.filter((id) => owners.includes(id)) : all;
}

function games({ changedFrom }) {
  const all = listGameIds();
  const changed = changedFrom ? git(["diff", "--name-only", changedFrom, "HEAD"]).split(/\r?\n/).filter(Boolean) : [];
  const selected = selectGames(all, changed);
  setOutput("games", JSON.stringify(selected));
  console.log(`Games: ${selected.join(", ") || "none (documentation only)"}`);
}

// The verdict of a CI run, from the results of the jobs it needs (NEEDS, the
// workflow's `needs` context as JSON): a job that failed or was cancelled
// fails it; one skipped because the run covers no game does not. Branch
// protection requires this one check rather than every job of the matrix.
function result() {
  const needs = JSON.parse(process.env.NEEDS || "{}");
  const lines = ["## CI result", "", "| Job | Result |", "| --- | --- |"];
  const failed = [];
  for (const [job, { result: outcome }] of Object.entries(needs)) {
    lines.push(`| ${job} | ${outcome} |`);
    if (outcome !== "success" && outcome !== "skipped") failed.push(`${job} (${outcome})`);
  }
  appendSummary(`${lines.join("\n")}\n`);
  if (Object.keys(needs).length === 0) fail("NEEDS holds no job results.");
  if (failed.length > 0) fail(`CI failed: ${failed.join(", ")}.`);
  console.log("Every job the run needs passed or had nothing to do.");
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
  const notes = rootPath("artifacts", `${game.id}-release-notes.md`);
  fs.mkdirSync(path.dirname(notes), { recursive: true });
  fs.writeFileSync(notes, releaseNotes(game, process.env.GITHUB_REF_NAME), "utf8");
  // A pre-release (0.2.0-beta.1) is marked as one and never as the latest.
  const prerelease = tag.version.includes("-") ? ["--prerelease", "--latest=false"] : [];
  console.log(
    await gh(["release", "create", process.env.GITHUB_REF_NAME, ...assets, "--repo", process.env.GITHUB_REPOSITORY, "--title", title, "--notes-file", notes, ...prerelease, "--verify-tag"]),
  );
}

// The notes of a game's release: the commits since the game's previous
// release that change the game, then those that change what it is built on
// (the core, its modules, its addons and the tools). The repository holds
// several games, so notes generated from every pull request would mix them.
function releaseNotes(game, tag) {
  const previous = git(["describe", "--tags", "--abbrev=0", "--match", `game/${game.id}/v*`, `${tag}^`], { optional: true });
  const range = previous ? `${previous.trim()}..${tag}` : tag;
  const commits = (paths) => git(["log", "--no-merges", "--format=- %s (%h)", range, "--", ...paths]).split(/\r?\n/).filter(Boolean);
  const own = commits([`games/${game.id}`]);
  const foundation = commits([
    "gamebase/core",
    ...game.modules.map((module) => `gamebase/modules/${module}`),
    ...game.addons.map((addon) => `addons/${addon}`),
    "tools",
    ".godot-version",
  ]).filter((line) => !own.includes(line));
  const lines = [`Changes since ${previous ? previous.trim() : "the start of the project"}.`, ""];
  lines.push(`## ${gameName(game)}`, "", ...(own.length > 0 ? own : ["- No change of its own."]), "");
  lines.push("## GameBase foundation", "", ...(foundation.length > 0 ? foundation : ["- No change."]), "");
  return lines.join("\n");
}

const COMMANDS = {
  "engine-version": (values) => engineVersion({ latest: values.latest }),
  games: (values) => games({ changedFrom: values["changed-from"] }),
  result: () => result(),
  release: (values) => release({ game: values.game }),
  "addon-issue": (values) => addonIssue({ updatesAvailable: values["updates-available"] === "true" }),
  "compat-summary": (values) => compatSummary({ baseline: values.baseline, version: values.version }),
  "append-summary": (values) => appendSummary(fs.readFileSync(path.resolve(values.file), "utf8")),
  "publish-release": (values) => publishRelease({ game: values.game }),
};

module.exports = { releaseNotes, selectGames };

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
