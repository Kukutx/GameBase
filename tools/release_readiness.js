const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { PRESET_NAMES, exportPresets } = require("./export");
const { packageTarget, targetsFor } = require("./package_release");
const { smokeExport } = require("./smoke_export");
const { validate } = require("./validate");
const { fail, git, main, npmCommand, resolveGodotBin, rootPath, run } = require("./lib/common");
const { distPath, gamePath, gameVersion, resolveGame } = require("./lib/games");

const REQUIRED = [
  "AGENTS.md",
  ".agents/rules/project.md",
  "docs/AUDIO.md",
  ".godot-version",
  ".github/workflows/ci.yml",
  ".github/workflows/release.yml",
  ".github/workflows/engine-compat.yml",
  "gamebase/gamebase.json",
  "tools/link.js",
  "tools/validate.js",
  "tools/validate_rules.js",
  "tools/check_localization.js",
  "tools/export.js",
  "tools/verify_export_contents.js",
  "tools/generate_release_manifest.js",
  "tools/package_release.js",
  "THIRD_PARTY_NOTICES.md",
  "licenses/GAMEBASE_LICENSE.txt",
  "licenses/GODOT_LICENSE.txt",
  "licenses/GODOT_COPYRIGHT.txt",
  "licenses/GODOT_VERSION.txt",
  "licenses/DIALOGUE_MANAGER_LICENSE.txt",
  "licenses/NOTO_SANS_SC_LICENSE.txt",
  "tools/install_export_templates.js",
  "tools/update_game_version.js",
  "tools/update_engine_baseline.js",
  "tools/smoke_export.js",
  "tools/web_smoke/run.js",
  "tools/web_smoke/package.json",
  "tools/web_smoke/package-lock.json",
];

// The game's own release files, beside what the repository shares.
const GAME_REQUIRED = ["game.json", "project.godot", "export_presets.cfg"];

// Walks real directories only: the links inside a game point back at the shared copy.
function findFiles(directory, name, found = []) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === ".git" || entry.name === ".dev" || entry.name === ".godot" || entry.name === "node_modules" || entry.isSymbolicLink()) {
      continue;
    }
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      findFiles(absolute, name, found);
    } else if (entry.name === name) {
      found.push(absolute);
    }
  }
  return found;
}

function checkRepository(game) {
  for (const relative of REQUIRED) {
    if (!fs.existsSync(rootPath(relative))) {
      fail(`Missing required release infrastructure: ${relative}`);
    }
  }
  for (const relative of GAME_REQUIRED) {
    if (!fs.existsSync(gamePath(game, relative))) {
      fail(`Missing required release file: games/${game.id}/${relative}`);
    }
  }
  gameVersion(game);
  if (findFiles(rootPath(), "CLAUDE.md").length > 0) {
    fail("CLAUDE.md is not allowed; AGENTS.md is the project instruction source.");
  }
  if (git(["ls-files", "--", "games/*/game/art/licensed"]).trim().length > 0) {
    fail("Purchased raw art is tracked by Git. Remove it before releasing.");
  }
  const dirty = git(["status", "--porcelain", "--untracked-files=all"]).trim();
  if (dirty.length > 0) {
    console.log(dirty);
    fail("Release readiness requires a clean Git working tree so BUILD_INFO.json can prove an exact commit.");
  }
}

async function browserSmoke(game) {
  const steps = [
    ["Installing deterministic Web smoke dependencies", ["ci", "--prefix", "tools/web_smoke", "--ignore-scripts"]],
    ["Ensuring Playwright Chromium is installed", ["exec", "--prefix", "tools/web_smoke", "--", "playwright", "install", "chromium"]],
    ["Browser smoke Web export", ["run", "--prefix", "tools/web_smoke", "smoke:web"]],
  ];
  for (const [title, args] of steps) {
    console.log("");
    console.log(`==> ${title}`);
    const result = await npmCommand(args, { env: { ...process.env, GAMEBASE_GAME: game.id } });
    if (result.code !== 0) {
      fail(`${title} failed with exit code ${result.code}.`);
    }
  }
}

async function releaseReadiness({ game, godotBin, skipValidation, skipExport, skipBrowserSmoke }) {
  const godot = resolveGodotBin(godotBin);
  checkRepository(game);

  // Vendored addon sources stay byte-for-byte close to upstream, including
  // whitespace an upstream release may carry.
  const whitespace = await run("git", ["diff", "--check", "--", ".", ":(exclude)addons/dialogue_manager/**", ":(exclude)addons/gut/**"]);
  if (whitespace.code !== 0) {
    fail("git diff --check reported whitespace errors in project-owned files.");
  }

  if (!skipValidation) {
    await validate({ godotBin: godot, games: [game.id], cleanImport: true });
  }

  if (!skipExport) {
    await exportPresets({ game, presets: PRESET_NAMES, godotBin: godot, skipValidation: true });
    await smokeExport({ game, targets: [process.platform === "win32" ? "Windows" : "Linux", "Web"] });
    if (!skipBrowserSmoke) {
      await browserSmoke(game);
    }

    console.log("");
    console.log("==> Deterministic release archives");
    const dist = distPath(game);
    fs.rmSync(dist, { recursive: true, force: true });
    fs.mkdirSync(dist, { recursive: true });
    const epoch = Math.max(0, Number(git(["show", "-s", "--format=%ct", "HEAD"]).trim()));
    const targets = targetsFor(game);
    for (const target of Object.keys(targets)) {
      packageTarget(target, targets[target].source, targets[target].output, epoch);
    }

    console.log("");
    console.log("==> Release package identity + manifest");
    const manifest = await run(process.execPath, [rootPath("tools", "generate_release_manifest.js"), "--game", game.id]);
    if (manifest.code !== 0) {
      fail(`Release manifest generation failed with exit code ${manifest.code}.`);
    }
  }

  console.log("");
  console.log("Release readiness checks passed.");
}

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: {
        game: { type: "string" },
        "godot-bin": { type: "string" },
        "skip-validation": { type: "boolean", default: false },
        "skip-export": { type: "boolean", default: false },
        "skip-browser-smoke": { type: "boolean", default: false },
      },
    });
    await releaseReadiness({
      game: resolveGame(values.game),
      godotBin: values["godot-bin"],
      skipValidation: values["skip-validation"],
      skipExport: values["skip-export"],
      skipBrowserSmoke: values["skip-browser-smoke"],
    });
  });
}
