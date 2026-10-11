// Repository-wide invariants of the monorepo: the engine baseline and its legal
// bundle, the shared addons, the game registry and the release workflow.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { checkLocalization } = require("./check_localization");
const { ENGINE_VERSION_RE, removeRecursive, rootPath, tempFile } = require("./lib/common");
const { gamePath, gameVersion, listGameIds, loadGame, parseReleaseTag, readFoundation, releaseTag, resolveGames } = require("./lib/games");
const { desiredLinks } = require("./link");
const { createGame } = require("./new_game");

const read = (...parts) => fs.readFileSync(rootPath(...parts), "utf8");
const pluginVersion = (addon) => (/^version="([^"]+)"$/m.exec(read("addons", addon, "plugin.cfg")) || [])[1];

test("the engine baseline is a stable Godot 4 release and the legal bundle matches it", () => {
  const baseline = read(".godot-version").trim();
  assert.match(baseline, ENGINE_VERSION_RE);
  assert.equal(read("licenses", "GODOT_VERSION.txt").trim(), baseline);
  for (const file of ["GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt", "GAMEBASE_LICENSE.txt", "DIALOGUE_MANAGER_LICENSE.txt"]) {
    assert.ok(fs.existsSync(rootPath("licenses", file)), file);
  }
});

test("shared addons carry stable versions that support the engine baseline", () => {
  const [major, minor] = read(".godot-version").trim().split(".").map(Number);
  for (const addon of fs.readdirSync(rootPath("addons"))) {
    assert.match(pluginVersion(addon) || "", /^\d+\.\d+\.\d+$/, `${addon} plugin.cfg version`);
  }
  const gut = JSON.parse(read("addons", "gut", "versions.json")).releases[pluginVersion("gut")];
  assert.ok(gut, "addons/gut/versions.json lists the installed GUT version");
  const [minMajor, minMinor] = gut.godot_min.split(".").map(Number);
  const [maxMajor, maxMinor] = gut.godot_max.split(".").map(Number);
  assert.ok(minMajor < major || (minMajor === major && minMinor <= minor), `GUT needs Godot ${gut.godot_min}`);
  assert.ok(maxMajor > major || (maxMajor === major && maxMinor >= minor), `GUT supports Godot up to ${gut.godot_max}`);
});

// What CI and the release tools need from every game.
function assertCompleteGame(game) {
  const id = game.id;
  assert.match(gameVersion(game), /^\d+\.\d+\.\d+/);
  for (const file of ["project.godot", "export_presets.cfg", ".gutconfig.json", "test/unit"]) {
    assert.ok(fs.existsSync(gamePath(game, file)), `games/${id}/${file}`);
  }
  const presets = fs.readFileSync(gamePath(game, "export_presets.cfg"), "utf8");
  for (const name of ["Windows Desktop", "Linux", "Web"]) assert.ok(presets.includes(`name="${name}"`), `${id} preset ${name}`);
  for (const filter of presets.matchAll(/^exclude_filter="([^"]*)"$/gm)) {
    const excluded = filter[1].split(",");
    for (const required of ["test/*", "addons/gut/*", "game/art/licensed/*", ".gutconfig.json", "game.json"]) {
      assert.ok(excluded.includes(required), `${id} export excludes ${required}`);
    }
  }
}

// Runs a check that reports on the console without printing its report.
function quietly(check) {
  const log = console.log;
  console.log = () => {};
  try {
    return check();
  } finally {
    console.log = log;
  }
}

test("every registered game is a complete game project", () => {
  const ids = listGameIds();
  assert.ok(ids.length > 0, "at least one game is registered");
  for (const id of ids) assertCompleteGame(loadGame(id));
});

test("a new game is complete and translated as it is created", () => {
  const out = tempFile("gamebase-new-game-test");
  try {
    const game = createGame({ id: "probe", name: "Probe Game", out });
    assertCompleteGame(game);
    const presets = fs.readFileSync(gamePath(game, "export_presets.cfg"), "utf8");
    assert.ok(presets.includes('export_path="' + path.relative(out, rootPath("build", "probe", "linux", "ProbeGame.x86_64")).split(path.sep).join("/") + '"'));
    assert.equal(quietly(() => checkLocalization(game)), 0);

    // The core's catalog has to be registered: a game does not translate the core again.
    const project = gamePath(game, "project.godot");
    fs.writeFileSync(project, fs.readFileSync(project, "utf8").replace('"res://gamebase/core/i18n/core.zh_CN.po", ', ""), "utf8");
    assert.equal(quietly(() => checkLocalization(game)), 1);
  } finally {
    removeRecursive(out);
  }
});

test("a catalog entry translates text of its own layer, and the core's text in the core", () => {
  const out = tempFile("gamebase-catalog-test");
  const log = console.log;
  const lines = [];
  try {
    const game = createGame({ id: "probe", name: "Probe Game", out });
    const catalog = gamePath(game, "game", "i18n", "ui.zh_CN.po");
    fs.appendFileSync(catalog, '\nmsgid "Spring"\nmsgstr "春"\n\nmsgid "Nobody says this"\nmsgstr "没人说"\n', "utf8");
    console.log = (line) => lines.push(String(line));
    assert.equal(checkLocalization(game), 1);
  } finally {
    console.log = log;
    removeRecursive(out);
  }
  assert.ok(lines.includes('LOCALIZATION_PROBLEM: res://game/i18n/ui.zh_CN.po translates "Spring" of gamebase/core: move it to that layer\'s catalog'));
  assert.ok(lines.includes('LOCALIZATION_PROBLEM: res://game/i18n/ui.zh_CN.po translates "Nobody says this", which no text of games/probe holds'));
});

test("a resource's player-facing field needs a translation, such as a control's name", () => {
  const out = tempFile("gamebase-resource-text-test");
  const log = console.log;
  const lines = [];
  try {
    const game = createGame({ id: "probe", name: "Probe Game", out });
    const control = gamePath(game, "game", "input", "jump.tres");
    fs.mkdirSync(path.dirname(control), { recursive: true });
    fs.writeFileSync(control, '[gd_resource type="Resource" format=3]\n\n[resource]\naction = &"jump"\ndisplay_name = "Probe Jump"\nkey = 32\n', "utf8");
    console.log = (line) => lines.push(String(line));
    assert.equal(checkLocalization(game), 1);
  } finally {
    console.log = log;
    removeRecursive(out);
  }
  assert.ok(lines.includes("LOCALIZATION_PROBLEM: games/probe (zh_CN): missing Probe Jump"));
});

test("GAMEBASE_GAME picks one game but never narrows a repository-wide step", () => {
  const saved = process.env.GAMEBASE_GAME;
  process.env.GAMEBASE_GAME = listGameIds()[0];
  try {
    assert.deepEqual(resolveGames().map((game) => game.id), listGameIds());
  } finally {
    if (saved === undefined) delete process.env.GAMEBASE_GAME;
    else process.env.GAMEBASE_GAME = saved;
  }
});

test("a game links the core, its modules and the addons they use", () => {
  const foundation = readFoundation();
  const game = { id: "probe", root: rootPath("games", "probe"), modules: ["items"], addons: ["gut"] };
  const links = desiredLinks(game).map(([link, target]) => [path.relative(rootPath(), link), path.relative(rootPath(), target)].map((p) => p.split(path.sep).join("/")));
  assert.deepEqual(links, [
    ["games/probe/gamebase/core", "gamebase/core"],
    ["games/probe/gamebase/modules/items", "gamebase/modules/items"],
    ["games/probe/addons/gut", "addons/gut"],
  ]);
  assert.ok(foundation.addons.includes("gut"), "every game links the test framework");
});

test("a release tag names one game and its version", () => {
  assert.deepEqual(parseReleaseTag("game/farm1/v1.2.3"), { id: "farm1", version: "1.2.3" });
  assert.equal(parseReleaseTag("v1.2.3"), null);
  assert.equal(releaseTag({ id: "farm1" }, "0.1.0"), "game/farm1/v0.1.0");
  const workflow = read(".github", "workflows", "release.yml");
  assert.ok(workflow.includes('- "game/*/v*"'), "release.yml triggers on game tags");
  assert.ok(!/^\s+- "v\*"$/m.test(workflow), "release.yml must not trigger on bare v* tags");
});

test("repository tooling is Node only", () => {
  const offenders = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (entry.name === "node_modules") continue;
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(file);
      else if ([".py", ".ps1", ".sh", ".bat", ".cmd", ".rb", ".pl"].includes(path.extname(entry.name).toLowerCase())) offenders.push(file);
    }
  };
  visit(rootPath("tools"));
  assert.deepEqual(offenders, []);
  for (const workflow of fs.readdirSync(rootPath(".github", "workflows"))) {
    const text = read(".github", "workflows", workflow);
    assert.ok(!text.includes("shell: pwsh"), `${workflow} must not use PowerShell`);
    assert.ok(!text.includes("setup-python"), `${workflow} must not set up Python`);
  }
});
