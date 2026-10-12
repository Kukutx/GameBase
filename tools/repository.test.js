// Repository-wide invariants of the monorepo: the engine baseline and its legal
// bundle, the shared addons, the game registry and the release workflow.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { checkLocalization } = require("./check_localization");
const { ENGINE_VERSION_RE, removeRecursive, rootPath, tempFile } = require("./lib/common");
const { assertAutoloadScripts, checkFoundation, checkGameAutoloads, gamePath, gameVersion, listGameIds, loadGame, parseReleaseTag, projectString, readFoundation, releaseTag, resolveGames, templateGame } = require("./lib/games");
const { desiredLinks } = require("./link");
const { desiredAutoloads, desiredTestDirs, moduleOrder, projectInSync, syncedGutConfig, syncedProject } = require("./lib/project");
const { createGame } = require("./new_game");
const { selectGames } = require("./ci");
const { callArguments, pages, ruleKeys, signalsOf, stalePages } = require("./generate_reference");

const read = (...parts) => fs.readFileSync(rootPath(...parts), "utf8");
const pluginVersion = (addon) => (/^version="([^"]+)"$/m.exec(read("addons", addon, "plugin.cfg")) || [])[1];

test("the engine baseline is a stable Godot 4 release and the legal bundle matches it", () => {
  const baseline = read(".godot-version").trim();
  assert.match(baseline, ENGINE_VERSION_RE);
  assert.equal(read("licenses", "GODOT_VERSION.txt").trim(), baseline);
  for (const file of ["GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt", "GAMEBASE_LICENSE.txt", "DIALOGUE_MANAGER_LICENSE.txt", "NOTO_SANS_SC_LICENSE.txt"]) {
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
    for (const required of ["test/*", "gamebase/core/test/*", "gamebase/modules/*/test/*", "addons/gut/*", "game/art/licensed/*", ".gutconfig.json", "game.json"]) {
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

test("a new game takes its description, with a catalog entry that keeps the English text until it is translated", () => {
  const out = tempFile("gamebase-description-test");
  try {
    const game = createGame({ id: "probe", name: "Probe Game", description: "A probe of the template · 试", out });
    assert.equal(projectString(game, "application", "config/description"), "A probe of the template · 试");
    const catalog = fs.readFileSync(gamePath(game, "game", "i18n", "ui.zh_CN.po"), "utf8");
    assert.ok(catalog.includes('msgid "A probe of the template · 试"\nmsgstr "A probe of the template · 试"\n'));
    assert.ok(!catalog.includes("New game on GameBase"));
    assert.equal(quietly(() => checkLocalization(game)), 0);
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

test("a resource's player-facing text needs a translation, such as a control's name, a skill's short name or a calendar's seasons", () => {
  const out = tempFile("gamebase-resource-text-test");
  const log = console.log;
  const lines = [];
  try {
    const game = createGame({ id: "probe", name: "Probe Game", out });
    const control = gamePath(game, "game", "input", "jump.tres");
    fs.mkdirSync(path.dirname(control), { recursive: true });
    fs.writeFileSync(control, '[gd_resource type="Resource" format=3]\n\n[resource]\naction = &"jump"\ndisplay_name = "Probe Jump"\nkey = 32\n', "utf8");
    const skill = gamePath(game, "game", "data", "skills", "probing.tres");
    fs.mkdirSync(path.dirname(skill), { recursive: true });
    fs.writeFileSync(skill, '[gd_resource type="Resource" format=3]\n\n[resource]\nid = &"probing"\nshort_name = "Probe Short"\n', "utf8");
    const calendar = gamePath(game, "game", "probe_calendar.tres");
    fs.writeFileSync(calendar, '[gd_resource type="Resource" format=3]\n\n[resource]\nseason_names = PackedStringArray("Spring", "Probe Dry")\n', "utf8");
    console.log = (line) => lines.push(String(line));
    assert.equal(checkLocalization(game), 1);
  } finally {
    console.log = log;
    removeRecursive(out);
  }
  assert.ok(lines.includes("LOCALIZATION_PROBLEM: games/probe (zh_CN): missing Probe Jump"));
  assert.ok(lines.includes("LOCALIZATION_PROBLEM: games/probe (zh_CN): missing Probe Short"));
  assert.ok(lines.includes("LOCALIZATION_PROBLEM: games/probe (zh_CN): missing Probe Dry"));
  assert.ok(!lines.some((line) => line.includes("missing Spring")), "the core translates its own seasons");
});

test("every game's project.godot and .gutconfig.json hold what its manifests give", () => {
  for (const id of listGameIds()) assert.ok(projectInSync(loadGame(id)), `games/${id}: run node tools/link.js`);
  assert.ok(projectInSync(templateGame()), "gamebase/templates/new_game: run node tools/link.js");
});

test("a game runs the tests of the core, of each of its modules and its own", () => {
  const foundation = readFoundation();
  const game = { id: "probe", root: rootPath("games", "probe"), modules: ["skills", "items"], addons: ["gut"], manifest: {} };
  const dirs = desiredTestDirs(game, foundation);
  assert.equal(dirs[0], "res://gamebase/core/test/");
  assert.equal(dirs[dirs.length - 1], "res://test/unit/");
  for (const dir of dirs.slice(1, -1)) assert.match(dir, /^res:\/\/gamebase\/modules\/(items|skills)\/test\/$/);
  const config = JSON.parse(syncedGutConfig('{"dirs": ["res://stale/"], "should_exit": true}', game, foundation));
  assert.deepEqual(config, { dirs, should_exit: true, pre_run_script: "res://gamebase/core/test/gut_pre_run.gd" });
});

test("a module's autoloads follow the modules it requires, between the core's", () => {
  const foundation = readFoundation();
  assert.deepEqual(moduleOrder(foundation, ["progression", "skills", "npc_social", "lifesim", "items", "combat"]), ["items", "combat", "skills", "lifesim", "npc_social", "progression"]);
  const game = { id: "probe", root: rootPath("games", "probe"), modules: ["skills", "items"], addons: ["gut"], manifest: { autoloads: { ProbeTools: "res://game/probe_tools.gd" } } };
  const names = desiredAutoloads(game, foundation).map(([name]) => name);
  const lastBefore = Object.keys(foundation.autoloads.before_modules).at(-1);
  const firstAfter = Object.keys(foundation.autoloads.after_modules)[0];
  assert.deepEqual(names.slice(names.indexOf(lastBefore) + 1, names.indexOf(firstAfter)), [...Object.keys(foundation.modules.items.autoloads), "Skills"]);
  assert.equal(names[0], "Transition");
  assert.equal(names[names.length - 1], "ProbeTools");
  const project = syncedProject('config_version=5\n\n[autoload]\n\nStale="*res://old.gd"\n\n[application]\n\nconfig/name="Probe"\n', game, foundation);
  assert.ok(!project.includes("Stale="), "the autoloads are replaced, not merged");
  assert.ok(project.includes('[application]\n\nconfig/name="Probe"\n'), "the game's own settings stay");
  assert.ok(project.includes('[editor_plugins]\n\nenabled=PackedStringArray("res://addons/gut/plugin.cfg")'));
});

test("the manifests reject autoloads that would break a linked game", () => {
  const core = { before_modules: { Events: "res://gamebase/core/events.gd" }, after_modules: {} };
  const manifest = (modules, autoloads = core) => ({ autoloads, modules });
  assert.throws(() => checkFoundation(manifest({}, [])), /gamebase\.json autoloads must be an object/);
  assert.throws(() => checkFoundation(manifest({ a: { autoloads: { Probe: "res://gamebase/modules/b/probe.gd" } }, b: {} })), /modules\.a\.autoloads\.Probe must be a script under res:\/\/gamebase\/modules\/a\//);
  const foundation = checkFoundation(manifest({ a: { addons: ["tool"], autoloads: { ToolService: "res://addons/tool/service.gd" } }, b: { requires: ["c"] }, c: { requires: ["b"] } }));
  assert.throws(() => checkGameAutoloads({ Events: "res://game/events.gd" }, "game.json autoloads", ["gut"], foundation), /Events is already declared by gamebase\.json autoloads\.before_modules/);
  assert.throws(() => checkGameAutoloads({ Probe: "res://gamebase/core/probe.gd" }, "game.json autoloads", ["gut"], foundation), /must be a script under res:\/\/game\/ or res:\/\/addons\/gut\//);
  assert.throws(() => assertAutoloadScripts({ Probe: "res://gamebase/core/probe.gd" }, "gamebase.json autoloads.after_modules"), /autoloads\.after_modules\.Probe names res:\/\/gamebase\/core\/probe\.gd, which does not exist/);
  assert.throws(() => assertAutoloadScripts({ Probe: "res://game/probe.gd" }, "game.json autoloads", rootPath("games", "farm1")), /Probe names res:\/\/game\/probe\.gd, which does not exist/);
  assertAutoloadScripts({ SaveManager: "res://gamebase/core/save/game_save_manager.gd", Setup: "res://game/game_setup.gd" }, "probe", rootPath("games", "farm1"));
  assert.throws(() => moduleOrder(foundation, ["a", "b", "c"]), /modules b, c cannot be ordered because their requires form a cycle/);
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

test("every workflow job has a time limit, and CI ends in one verdict over every job", () => {
  for (const workflow of fs.readdirSync(rootPath(".github", "workflows"))) {
    const jobs = read(".github", "workflows", workflow).split(/^jobs:$/m)[1].split(/^ {2}(?=[\w-]+:$)/m).slice(1);
    assert.ok(jobs.length > 0, `${workflow} has jobs`);
    for (const job of jobs) {
      assert.match(job, /^ {4}timeout-minutes: \d+$/m, `${workflow} job ${job.split(":")[0]} sets timeout-minutes`);
    }
  }
  const ci = read(".github", "workflows", "ci.yml");
  const jobNames = [...ci.split(/^jobs:$/m)[1].matchAll(/^ {2}([\w-]+):$/gm)].map((match) => match[1]).filter((name) => name !== "result");
  const verdict = /^ {2}result:\n(?: {4}.*\n)*? {4}needs: \[([^\]]*)\]/m.exec(ci);
  assert.ok(verdict, "ci.yml has a result job");
  assert.deepEqual(verdict[1].split(",").map((name) => name.trim()).sort(), jobNames.sort(), "the result job needs every other job");
});

test("a pull request runs the games it changes, every game for a shared change and none for documentation", () => {
  const all = ["dungeon1", "farm1"];
  assert.deepEqual(selectGames(all, []), all, "a push or a manual run");
  assert.deepEqual(selectGames(all, ["README.md", "docs/RELEASE.md", ".agents/rules/save.md"]), []);
  assert.deepEqual(selectGames(all, ["games/farm1/game/a.gd", "games/farm1/README.md", "docs/A.md"]), ["farm1"]);
  assert.deepEqual(selectGames(all, ["gamebase/core/a.gd", "games/farm1/game/a.gd"]), all);
  assert.deepEqual(selectGames(all, ["tools/ci.js"]), all);
});

test("the reference pages name every autoload with what it does and every rule key with what it means", () => {
  assert.deepEqual(stalePages(), [], "run node tools/generate_reference.js");
  const foundation = readFoundation();
  const reference = pages(foundation);
  const names = [
    ...Object.keys(foundation.autoloads.before_modules),
    ...Object.values(foundation.modules).flatMap((module) => Object.keys(module.autoloads || {})),
    ...Object.keys(foundation.autoloads.after_modules),
  ];
  for (const name of names) {
    const row = reference["autoloads.md"].split("\n").find((line) => line.startsWith(`| \`${name}\` |`));
    assert.ok(row, `autoloads.md lists ${name}`);
    assert.ok(!row.endsWith("|  |"), `${name}'s script has a class doc saying what it does`);
  }
  for (const entry of ruleKeys()) {
    assert.ok(entry.meaning, `${entry.file}: ${entry.key} has a doc comment "## ${entry.key} <args>: what it means"`);
  }
  assert.deepEqual(callArguments('&"KEY", _f.bind(a, "b, c"), 1, -1, [X, Y])', 0), ['&"KEY"', '_f.bind(a, "b, c")', "1", "-1", "[X, Y]"]);
  assert.deepEqual(signalsOf("## Done.\nsignal done(at: int)\nsignal bare\n"), [
    { name: "done", params: "(at: int)", doc: "Done." },
    { name: "bare", params: "()", doc: "" },
  ]);
});
