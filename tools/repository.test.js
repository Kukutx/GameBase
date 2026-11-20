// Repository-wide invariants of the monorepo: the engine baseline and its legal
// bundle, the shared addons, the game registry and the release workflow.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { checkLocalization, collectNonDialogueKeys, layerLiterals, repeatProblem } = require("./check_localization");
const { androidIconPaths, expectedRecord, staleAndroidIcon } = require("./lib/android_icon");
const { ENGINE_VERSION_RE, removeRecursive, rootPath, tempFile } = require("./lib/common");
const { assertAutoloadScripts, checkFoundation, checkGameAutoloads, gamePath, gameVersion, listGameIds, loadGame, parseReleaseTag, projectString, readFoundation, releaseTag, resolveGames, templateGame } = require("./lib/games");
const { desiredLinks } = require("./link");
const { desiredAddonExcludes, desiredAutoloads, desiredTestDirs, moduleOrder, poTranslation, projectInSync, stampedProject, syncedExportPresets, syncedGutConfig, syncedProject } = require("./lib/project");
const { createGame } = require("./new_game");
const { PRESET_NAMES, androidVersionCode, applicationId } = require("./lib/targets");
const { runWithin, selectGames } = require("./ci");
const { callArguments, pages, ruleKeys, signalsOf, stalePages } = require("./generate_reference");
const { findTestScripts } = require("./validate");

const read = (...parts) => fs.readFileSync(rootPath(...parts), "utf8");
const pluginVersion = (addon) => (/^version="([^"]+)"$/m.exec(read("addons", addon, "plugin.cfg")) || [])[1];

test("the engine baseline is a stable Godot 4 release and the legal bundle matches it", () => {
  const baseline = read(".godot-version").trim();
  assert.match(baseline, ENGINE_VERSION_RE);
  assert.equal(read("licenses", "GODOT_VERSION.txt").trim(), baseline);
  for (const file of ["GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt", "TIAMAT_LICENSE.txt", "DIALOGUE_MANAGER_LICENSE.txt", "NOTO_SANS_SC_LICENSE.txt"]) {
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
  for (const name of PRESET_NAMES) assert.ok(presets.includes(`name="${name}"`), `${id} preset ${name}`);
  // A phone, a Mac and a window title show the game's own icon.
  const icon = projectString(game, "application", "config/icon");
  assert.ok(icon && icon.startsWith("res://"), `${id} sets config/icon`);
  assert.ok(fs.existsSync(gamePath(game, icon.slice("res://".length))), `${id} icon ${icon} exists`);
  for (const filter of presets.matchAll(/^exclude_filter="([^"]*)"$/gm)) {
    const excluded = filter[1].split(",");
    for (const required of ["test/*", "tiamat/core/test/*", "tiamat/modules/*/test/*", "addons/gut/*", "game/art/licensed/*", ".gutconfig.json", "game.json"]) {
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
  const out = tempFile("tiamat-new-game-test");
  try {
    const game = createGame({ id: "probe", name: "Probe Game", out });
    assertCompleteGame(game);
    const presets = fs.readFileSync(gamePath(game, "export_presets.cfg"), "utf8");
    assert.ok(presets.includes('export_path="' + path.relative(out, rootPath("build", "probe", "linux", "ProbeGame.x86_64")).split(path.sep).join("/") + '"'));
    assert.equal(quietly(() => checkLocalization(game)), 0);

    // The core's catalog has to be registered: a game does not translate the core again.
    const project = gamePath(game, "project.godot");
    fs.writeFileSync(project, fs.readFileSync(project, "utf8").replace('"res://tiamat/core/i18n/core.zh_CN.po", ', ""), "utf8");
    assert.equal(quietly(() => checkLocalization(game)), 1);
  } finally {
    removeRecursive(out);
  }
});

test("a new game takes the modules it names with every module they require", () => {
  const out = tempFile("tiamat-new-game-modules-test");
  try {
    assert.throws(() => createGame({ id: "probe", name: "Probe Game", modules: ["boats"], out }), /Unknown module 'boats'/);
    assert.equal(fs.existsSync(out) && fs.readdirSync(out).length > 0, false, "a refused game writes nothing");
    const game = createGame({ id: "probe", name: "Probe Game", modules: ["npc_ai", "combat", "combat"], out });
    const listed = ["combat", "damage", "dialogue", "items", "npc_ai", "npc_social"];
    assert.deepEqual(game.modules, listed);
    assert.deepEqual(JSON.parse(fs.readFileSync(gamePath(game, "game.json"), "utf8")), { id: "probe", modules: listed });
    assert.ok(game.addons.includes("dialogue_manager"), "the addon its modules use");
    assert.ok(projectInSync(game), "linked: the modules' autoloads and catalogs are registered");
    const project = fs.readFileSync(gamePath(game, "project.godot"), "utf8");
    assert.ok(project.includes('"res://tiamat/modules/npc_social/i18n/npc_social.zh_CN.po"'));
    assert.equal(quietly(() => checkLocalization(game)), 0);
  } finally {
    removeRecursive(out);
  }
});

test("a new game takes its description, with a catalog entry that keeps the English text until it is translated", () => {
  const out = tempFile("tiamat-description-test");
  try {
    const game = createGame({ id: "probe", name: "Probe Game", description: "A probe of the template · 试", out });
    assert.equal(projectString(game, "application", "config/description"), "A probe of the template · 试");
    const catalog = fs.readFileSync(gamePath(game, "game", "i18n", "ui.zh_CN.po"), "utf8");
    assert.ok(catalog.includes('msgid "A probe of the template · 试"\nmsgstr "A probe of the template · 试"\n'));
    assert.ok(!catalog.includes("New game on Tiamat"));
    assert.equal(quietly(() => checkLocalization(game)), 0);
  } finally {
    removeRecursive(out);
  }
});

test("a catalog entry translates text of its own layer, and the core's text in the core", () => {
  const out = tempFile("tiamat-catalog-test");
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
  assert.ok(lines.includes('LOCALIZATION_PROBLEM: res://game/i18n/ui.zh_CN.po translates "Spring" of tiamat/core: move it to that layer\'s catalog'));
  assert.ok(lines.includes('LOCALIZATION_PROBLEM: res://game/i18n/ui.zh_CN.po translates "Nobody says this", which no text of games/probe holds'));
});

test("text two modules hold is translated by the lower one, or alike by each when neither requires the other", () => {
  const core = { name: "tiamat/core", below: [] };
  const items = { name: "tiamat/modules/items", below: ["tiamat/core"] };
  const farm = { name: "tiamat/modules/farm", below: ["tiamat/core", "tiamat/modules/items"] };
  const quests = { name: "tiamat/modules/quests", below: ["tiamat/core", "tiamat/modules/items"] };
  const entry = (layer, text) => ({ res: `res://${layer.name}.po`, layer, text });
  assert.equal(repeatProblem(entry(farm, '"已领取"'), entry(quests, '"已领取"'), "Claimed"), "");
  assert.equal(repeatProblem(entry(farm, '"已领取"'), entry(quests, '"领了"'), "Claimed"), 'res://tiamat/modules/quests.po translates "Claimed" otherwise than res://tiamat/modules/farm.po does');
  assert.equal(repeatProblem(entry(items, '"已领取"'), entry(farm, '"已领取"'), "Claimed"), 'res://tiamat/modules/farm.po repeats "Claimed", which res://tiamat/modules/items.po already translates');
  assert.equal(repeatProblem(entry(farm, '"已领取"'), entry(core, '"已领取"'), "Claimed"), 'res://tiamat/core.po repeats "Claimed", which res://tiamat/modules/farm.po already translates');
});

test("a count's text needs a plural entry with every form its language has", () => {
  const out = tempFile("tiamat-plural-test");
  const log = console.log;
  const runs = [];
  try {
    const game = createGame({ id: "probe", name: "Probe Game", out });
    const script = gamePath(game, "game", "probe_counter.gd");
    fs.writeFileSync(script, 'extends Node\n\nfunc text(count: int) -> String:\n\treturn tr_n("%d probe apple", "%d probe apples", count) % count\n', "utf8");
    const catalog = gamePath(game, "game", "i18n", "ui.zh_CN.po");
    const base = fs.readFileSync(catalog, "utf8");
    const check = (entry) => {
      fs.writeFileSync(catalog, base + entry, "utf8");
      const lines = [];
      console.log = (line) => lines.push(String(line));
      const result = checkLocalization(game);
      console.log = log;
      runs.push(lines);
      return result;
    };
    assert.equal(check(""), 1);
    assert.equal(check('\nmsgid "%d probe apple"\nmsgstr "%d 个探针苹果"\n'), 1);
    assert.equal(check('\nmsgid "%d probe apple"\nmsgid_plural "%d probe pears"\nmsgstr[0] "%d 个探针苹果"\n'), 1);
    assert.equal(check('\nmsgid "%d probe apple"\nmsgid_plural "%d probe apples"\nmsgstr[0] ""\n'), 1);
    assert.equal(check('\nmsgid "%d probe apple"\nmsgid_plural "%d probe apples"\nmsgstr[0] "%d 个探针苹果"\n'), 0);
  } finally {
    console.log = log;
    removeRecursive(out);
  }
  assert.ok(runs[0].includes("LOCALIZATION_PROBLEM: games/probe (zh_CN): missing plural %d probe apple"));
  assert.ok(runs[1].includes('LOCALIZATION_PROBLEM: games/probe (zh_CN): "%d probe apple" is translated without its plural "%d probe apples"'));
  assert.ok(runs[2].includes('LOCALIZATION_PROBLEM: games/probe (zh_CN): the plural of "%d probe apple" is "%d probe apples", not "%d probe pears"'));
  assert.ok(runs[3].includes('LOCALIZATION_PROBLEM: games/probe (zh_CN): "%d probe apple" needs 1 plural form(s), not 0'));
});

test("a resource's player-facing text needs a translation, such as a control's name, a skill's short name or a calendar's seasons", () => {
  const out = tempFile("tiamat-resource-text-test");
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

test("every game's project.godot, .gutconfig.json and export filters hold what its manifests give", () => {
  for (const id of listGameIds()) assert.ok(projectInSync(loadGame(id)), `games/${id}: run node tools/link.js`);
  assert.ok(projectInSync(templateGame()), "tiamat/templates/new_game: run node tools/link.js");
});

test("every game's Android launcher icon is drawn from its icon as it is now, and its preset names it", () => {
  const { foreground, background } = androidIconPaths();
  for (const game of [...listGameIds().map(loadGame), templateGame()]) {
    assert.equal(staleAndroidIcon(game), null);
    const presets = fs.readFileSync(gamePath(game, "export_presets.cfg"), "utf8");
    assert.ok(presets.includes(`launcher_icons/adaptive_foreground_432x432="${foreground}"`), `${game.id} names its foreground`);
    assert.ok(presets.includes(`launcher_icons/adaptive_background_432x432="${background}"`), `${game.id} names its background`);
    if (game.template) continue;
    assert.ok(presets.includes("splash_screen/disable_godot_boot_splash=true"), `${game.id} opens on Android's splash, not the engine's logo`);
    const project = fs.readFileSync(gamePath(game, "project.godot"), "utf8");
    assert.ok(project.includes(`boot_splash/image="${foreground}"`), `${game.id} boots on its own icon`);
    assert.match(project, /^boot_splash\/bg_color=Color\(/m, `${game.id} boots on its icon's colour`);
  }
});

test("a changed icon asks for its launcher layers to be drawn again, and a game without them names none", () => {
  const root = tempFile("tiamat-android-icon-test");
  const game = { id: "probe", root, modules: [], addons: [], manifest: {} };
  try {
    fs.mkdirSync(path.join(root, "android_icon"), { recursive: true });
    fs.writeFileSync(path.join(root, "project.godot"), '[application]\n\nconfig/name="Probe"\nconfig/version="0.1.0"\nconfig/icon="res://icon.svg"\n');
    fs.writeFileSync(path.join(root, "icon.svg"), "<svg/>");
    assert.match(staleAndroidIcon(game), /has no android_icon/);
    const presets = read("tiamat", "templates", "new_game", "export_presets.cfg");
    const bare = syncedExportPresets(presets, game);
    assert.ok(bare.includes('launcher_icons/adaptive_foreground_432x432=""'), "without layers Godot draws the whole icon");
    for (const name of ["foreground.png", "background.png"]) fs.writeFileSync(path.join(root, "android_icon", name), "");
    fs.writeFileSync(path.join(root, "android_icon", "icon.json"), JSON.stringify(expectedRecord(game)));
    assert.equal(staleAndroidIcon(game), null);
    assert.ok(syncedExportPresets(presets, game).includes('launcher_icons/adaptive_foreground_432x432="res://android_icon/foreground.png"'));
    const project = fs.readFileSync(path.join(root, "project.godot"), "utf8");
    assert.ok(!syncedProject(project, game).includes("boot_splash"), "layers drawn before records kept their colour change no splash");
    fs.writeFileSync(path.join(root, "android_icon", "icon.json"), JSON.stringify({ ...expectedRecord(game), background: "#FF8000" }));
    const booted = syncedProject(project, game);
    assert.ok(booted.includes("boot_splash/bg_color=Color(1, 0.502, 0, 1)\n"), "the background's colour");
    assert.ok(booted.includes('boot_splash/image="res://android_icon/foreground.png"\n'), "the foreground");
    assert.ok(booted.includes("boot_splash/stretch_mode=0\n"), "at its own size");
    fs.writeFileSync(path.join(root, "icon.svg"), "<svg width='2'/>");
    assert.match(staleAndroidIcon(game), /icon changed .*render_android_icon\.js --game probe/);
  } finally {
    removeRecursive(root);
  }
});

test("an export's project names the build it is made as, and nothing else changes", () => {
  const project = read("games", "mfarm", "project.godot");
  const stamped = stampedProject(project, "4c812db-dirty");
  assert.match(stamped, /^\[tiamat\]\n\nbuild="4c812db-dirty"\n/m);
  assert.equal(stamped.replace('build="4c812db-dirty"\n', ""), project);
  assert.equal(stampedProject(stamped, "4c812db-dirty"), stamped, "a stamp twice is one stamp");
});

test("a game runs the tests of the core, of each of its modules and its own", () => {
  const foundation = readFoundation();
  const game = { id: "probe", root: rootPath("games", "probe"), modules: ["skills", "items"], addons: ["gut"], manifest: {} };
  const dirs = desiredTestDirs(game, foundation);
  assert.equal(dirs[0], "res://tiamat/core/test/");
  assert.equal(dirs[dirs.length - 1], "res://test/unit/");
  for (const dir of dirs.slice(1, -1)) assert.match(dir, /^res:\/\/tiamat\/modules\/(items|skills)\/test\/$/);
  const config = JSON.parse(syncedGutConfig('{"dirs": ["res://stale/"], "should_exit": true}', game, foundation));
  assert.deepEqual(config, { dirs, should_exit: true, pre_run_script: "res://tiamat/core/test/gut_pre_run.gd" });
});

test("a game's exports keep out the editor files of the addons it links, and only those", () => {
  const talking = { id: "probe", addons: ["gut", "dialogue_manager"], template: true };
  const editorFiles = desiredAddonExcludes(talking);
  assert.ok(editorFiles.includes("addons/dialogue_manager/plugin.gd*"));
  const presets = 'name="Linux"\nexclude_filter="test/*,game.json"\n\nname="Web"\nexclude_filter="test/*,game.json"\n';
  const synced = syncedExportPresets(presets, talking);
  for (const filter of synced.matchAll(/^exclude_filter="([^"]*)"$/gm)) {
    assert.deepEqual(filter[1].split(","), ["test/*", "game.json", ...editorFiles]);
  }
  assert.equal(syncedExportPresets(synced, talking), synced, "a synced file stays as it is");
  assert.equal(syncedExportPresets(synced, { id: "probe", addons: ["gut"], template: true }), presets, "an addon the game no longer links takes its filters along");
});

test("linking gives a game a preset for every target, exporting to its build directory under its application id", () => {
  const out = tempFile("tiamat-presets-test");
  try {
    const game = createGame({ id: "probe-game", name: "Probe Game", out });
    const file = gamePath(game, "export_presets.cfg");
    const complete = fs.readFileSync(file, "utf8");
    // A game made before macOS and Android were targets has three presets.
    const old = complete.slice(0, complete.indexOf("[preset.3]")).replace(/\n+$/, "\n");
    const synced = syncedExportPresets(old, game);
    assert.equal(synced, complete, "the missing presets come from the template, filled in for the game");
    assert.equal(syncedExportPresets(synced, game), synced, "a synced file stays as it is");
    const relative = (...parts) => path.relative(out, rootPath("build", "probe-game", ...parts)).split(path.sep).join("/");
    assert.ok(synced.includes(`export_path="${relative("macos", "ProbeGame.app")}"`));
    assert.ok(synced.includes(`export_path="${relative("android", "ProbeGame.apk")}"`));
    assert.equal(applicationId(game), "io.github.kukutx.probe_game", "a package name has no hyphen");
    assert.ok(synced.includes('application/bundle_identifier="io.github.kukutx.probe_game"'));
    assert.ok(synced.includes('package/unique_name="io.github.kukutx.probe_game"'));
    assert.ok(synced.includes("version/code=100"), "0.1.0 is version code 100");
    assert.ok(synced.includes("permissions/internet=false"), "a game without npc_ai stays offline");
    assert.ok(synced.includes("permissions/vibrate=true"), "the core shakes the phone (Haptics)");
    // A key typed into the file by hand goes: signing keys come from the environment.
    const leaked = synced.replace('keystore/release_password=""', 'keystore/release_password="hunter2"');
    assert.ok(!syncedExportPresets(leaked, game).includes("hunter2"));
  } finally {
    removeRecursive(out);
  }
});

test("an Android version code grows with the game's version", () => {
  assert.equal(androidVersionCode("0.1.0"), 100);
  assert.equal(androidVersionCode("1.2.3-beta.1"), 10203);
  assert.ok(androidVersionCode("2.0.0") > androidVersionCode("1.99.99"));
  assert.throws(() => androidVersionCode("1.100.0"), /at most 99/);
});

test("a game whose modules reach the internet may do so on Android, and only then; every game may shake the phone", () => {
  for (const id of listGameIds()) {
    const game = loadGame(id);
    const presets = fs.readFileSync(gamePath(game, "export_presets.cfg"), "utf8");
    const online = game.modules.includes("npc_ai");
    assert.ok(presets.includes(`permissions/internet=${online}`), `${id} permissions/internet=${online}`);
    assert.ok(presets.includes("permissions/vibrate=true"), `${id} permissions/vibrate=true`);
  }
});

test("a battle on a grid or an open field needs no items", () => {
  const foundation = readFoundation();
  const below = (module) => (foundation.modules[module].requires || []).flatMap((required) => [required, ...below(required)]);
  for (const module of ["rts", "tactics"]) assert.deepEqual([...new Set(below(module))], ["damage"], module);
  assert.deepEqual(below("damage"), []);
});

test("a module's autoloads follow the modules it requires, between the core's", () => {
  const foundation = readFoundation();
  assert.deepEqual(moduleOrder(foundation, ["progression", "skills", "npc_social", "lifesim", "items", "dialogue", "combat", "damage"]), ["damage", "dialogue", "items", "combat", "npc_social", "skills", "lifesim", "progression"]);
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

test("a game's name in each language its own catalogs give names its window and its phone app", () => {
  const root = tempFile("tiamat-name");
  try {
    fs.mkdirSync(path.join(root, "game", "i18n"), { recursive: true });
    fs.writeFileSync(path.join(root, "game", "i18n", "ui.zh_CN.po"), 'msgid ""\nmsgstr ""\n"Language: zh_CN\\n"\n\nmsgid "Probe"\nmsgstr "探针"\n');
    const game = { id: "probe", root, modules: [], addons: [], manifest: {} };
    const before = 'config_version=5\n\n[application]\n\nconfig/name="Probe"\nconfig/name_localized={\n"ja": "プローブ",\n"zh_CN": "旧名"\n}\nconfig/version="1.0.0"\n';
    const project = syncedProject(before, game, readFoundation());
    assert.ok(project.includes('config/name_localized={\n"ja": "プローブ",\n"zh_CN": "探针"\n}\nconfig/quit_on_go_back=false\nconfig/version="1.0.0"'), "the catalog's name, and a language named by hand stays");
    assert.equal(syncedProject(project, game, readFoundation()), project, "linking again changes nothing");
    const unnamed = syncedProject('config_version=5\n\n[application]\n\nconfig/name="Other"\n', game, readFoundation());
    assert.ok(!unnamed.includes("name_localized"), "a name no catalog translates is left as it is");
    assert.equal(poTranslation('msgid "A"\nmsgstr ""\n', "A"), "", "an entry left empty translates nothing");
  } finally {
    removeRecursive(root);
  }
});

test("a phone held either way up shows a game the right way up", () => {
  const game = { id: "probe", root: tempFile("tiamat-orientation"), modules: [], addons: [], manifest: {} };
  const orientation = (display) => /window\/handheld\/orientation=(\d)/.exec(syncedProject(`config_version=5\n\n[display]\n\n${display}`, game, readFoundation()))?.[1];
  assert.equal(orientation("window/size/viewport_width=480\nwindow/size/viewport_height=270\n"), "4", "a wide view turns with the phone in landscape");
  assert.equal(orientation("window/size/viewport_width=360\nwindow/size/viewport_height=540\n"), "5", "a tall view turns with the phone in portrait");
  assert.equal(orientation(""), "4", "Godot's default view is wide");
  assert.equal(orientation("window/handheld/orientation=1\nwindow/size/viewport_width=480\n"), "1", "a game that names an orientation keeps it");
  const wide = syncedProject("config_version=5\n\n[display]\n\nwindow/size/viewport_width=480\nwindow/size/viewport_height=270\n", game, readFoundation());
  assert.ok(wide.includes("[display]\n\nwindow/handheld/orientation=4\nwindow/size/viewport_width=480\n"), "where the editor would write it");
  assert.equal(syncedProject(wide, game, readFoundation()), wide, "linking again changes nothing");
  assert.ok(!syncedProject("config_version=5\n", { ...game, template: true }, readFoundation()).includes("orientation"), "the template leaves it to each new game");
});

test("the manifests reject autoloads that would break a linked game", () => {
  const core = { before_modules: { Events: "res://tiamat/core/events.gd" }, after_modules: {} };
  const manifest = (modules, autoloads = core) => ({ autoloads, modules });
  assert.throws(() => checkFoundation(manifest({}, [])), /tiamat\.json autoloads must be an object/);
  assert.throws(() => checkFoundation(manifest({ a: { autoloads: { Probe: "res://tiamat/modules/b/probe.gd" } }, b: {} })), /modules\.a\.autoloads\.Probe must be a script under res:\/\/tiamat\/modules\/a\//);
  const foundation = checkFoundation(manifest({ a: { addons: ["tool"], autoloads: { ToolService: "res://addons/tool/service.gd" } }, b: { requires: ["c"] }, c: { requires: ["b"] } }));
  assert.throws(() => checkGameAutoloads({ Events: "res://game/events.gd" }, "game.json autoloads", ["gut"], foundation), /Events is already declared by tiamat\.json autoloads\.before_modules/);
  assert.throws(() => checkGameAutoloads({ Probe: "res://tiamat/core/probe.gd" }, "game.json autoloads", ["gut"], foundation), /must be a script under res:\/\/game\/ or res:\/\/addons\/gut\//);
  assert.throws(() => assertAutoloadScripts({ Probe: "res://tiamat/core/probe.gd" }, "tiamat.json autoloads.after_modules"), /autoloads\.after_modules\.Probe names res:\/\/tiamat\/core\/probe\.gd, which does not exist/);
  assert.throws(() => assertAutoloadScripts({ Probe: "res://game/probe.gd" }, "game.json autoloads", rootPath("games", "farm1")), /Probe names res:\/\/game\/probe\.gd, which does not exist/);
  assertAutoloadScripts({ SaveManager: "res://tiamat/core/save/game_save_manager.gd", Setup: "res://game/game_setup.gd" }, "probe", rootPath("games", "farm1"));
  assert.throws(() => moduleOrder(foundation, ["a", "b", "c"]), /modules b, c cannot be ordered because their requires form a cycle/);
});

test("TIAMAT_GAME picks one game but never narrows a repository-wide step", () => {
  const saved = process.env.TIAMAT_GAME;
  process.env.TIAMAT_GAME = listGameIds()[0];
  try {
    assert.deepEqual(resolveGames().map((game) => game.id), listGameIds());
  } finally {
    if (saved === undefined) delete process.env.TIAMAT_GAME;
    else process.env.TIAMAT_GAME = saved;
  }
});

test("a game links the core, its modules and the addons they use", () => {
  const foundation = readFoundation();
  const game = { id: "probe", root: rootPath("games", "probe"), modules: ["items"], addons: ["gut"] };
  const links = desiredLinks(game).map(([link, target]) => [path.relative(rootPath(), link), path.relative(rootPath(), target)].map((p) => p.split(path.sep).join("/")));
  assert.deepEqual(links, [
    ["games/probe/tiamat/core", "tiamat/core"],
    ["games/probe/tiamat/modules/items", "tiamat/modules/items"],
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

test("a CI step that runs past its time is stopped with what it started, and one that ends in time keeps its exit code", async () => {
  const started = Date.now();
  const stalled = await runWithin(process.execPath, ["-e", "require('node:child_process').spawn(process.execPath, ['-e', 'setTimeout(() => {}, 60000)'], { stdio: 'inherit' }); setTimeout(() => {}, 60000)"], 0.5);
  assert.deepEqual(stalled, { code: 1, timedOut: true });
  assert.ok(Date.now() - started < 10000, "it does not wait for the stalled process");
  assert.deepEqual(await runWithin(process.execPath, ["-e", "process.exit(3)"], 30), { code: 3, timedOut: false });
  assert.deepEqual(await runWithin(process.execPath, ["-e", ""], 30), { code: 0, timedOut: false });
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
  assert.deepEqual(selectGames(all, ["tiamat/core/a.gd", "games/farm1/game/a.gd"]), all);
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

test("validate --test finds a GUT script in the test directories a game runs, and only there", () => {
  const root = tempFile("tiamat-test-script");
  try {
    for (const dir of ["shared/test/menus", "test/unit", "other"]) fs.mkdirSync(path.join(root, dir), { recursive: true });
    fs.writeFileSync(path.join(root, "shared/test/menus/test_shop.gd"), "");
    fs.writeFileSync(path.join(root, "test/unit/test_shop_sign.gd"), "");
    fs.writeFileSync(path.join(root, "other/test_lonely.gd"), "");
    const config = { include_subdirs: true, dirs: ["res://shared/test/", "res://test/unit"] };
    fs.writeFileSync(path.join(root, ".gutconfig.json"), JSON.stringify(config));
    const game = { root };
    assert.deepEqual(findTestScripts(game, "test_shop.gd"), ["res://shared/test/menus/test_shop.gd"]);
    assert.deepEqual(findTestScripts(game, "test_shop_sign.gd"), ["res://test/unit/test_shop_sign.gd"]);
    assert.deepEqual(findTestScripts(game, "test_lonely.gd"), [], "a directory the game does not test");
    assert.deepEqual(findTestScripts(game, "res://other/test_lonely.gd"), [], "nor by its path");
    // A module's script and the game's may share a name: both are found, and
    // each can be named by its path.
    fs.writeFileSync(path.join(root, "test/unit/test_shop.gd"), "");
    assert.deepEqual(findTestScripts(game, "test_shop.gd"), ["res://shared/test/menus/test_shop.gd", "res://test/unit/test_shop.gd"]);
    assert.deepEqual(findTestScripts(game, "res://test/unit/test_shop.gd"), ["res://test/unit/test_shop.gd"]);
    assert.deepEqual(findTestScripts(game, "res://test/unit/test_gone.gd"), []);
    fs.writeFileSync(path.join(root, ".gutconfig.json"), JSON.stringify({ ...config, include_subdirs: false }));
    assert.deepEqual(findTestScripts(game, "test_shop.gd"), ["res://test/unit/test_shop.gd"], "without subdirectories");
    assert.deepEqual(findTestScripts(game, "res://shared/test/menus/test_shop.gd"), []);
  } finally {
    removeRecursive(root);
  }
});

test("the localization check reads what each control on a HUD does from scenes and script defaults", () => {
  const root = tempFile("tiamat-hint-text");
  try {
    fs.mkdirSync(root, { recursive: true });
    fs.writeFileSync(path.join(root, "hud.tscn"), [
      '[node name="Controls" type="Label" parent="."]',
      "hints = Dictionary[StringName, String]({",
      '&"move": "walk",',
      '&"quick_save/quick_load": "save/load"',
      "})",
      'text = ""',
      "",
    ].join("\n"));
    fs.writeFileSync(path.join(root, "line.gd"), [
      "@export var hints: Dictionary[StringName, String] = {",
      '\t&"interact": "use",',
      "}",
      "",
    ].join("\n"));
    const layer = { name: "fixture", root };
    const keys = collectNonDialogueKeys(layer);
    for (const text of ["walk", "save/load", "use"]) assert.ok(keys.has(text), text);
    assert.ok(!keys.has("move") && !keys.has("interact"), "a control's id is no text");
    assert.ok(layerLiterals(layer).has("save/load"));
  } finally {
    removeRecursive(root);
  }
});
