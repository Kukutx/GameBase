// Repository-wide invariants of the monorepo: the engine baseline and its legal
// bundle, the shared addons, the game registry and the release workflow.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { ENGINE_VERSION_RE, rootPath } = require("./lib/common");
const { gamePath, gameVersion, listGameIds, loadGame, parseReleaseTag, readFoundation, releaseTag } = require("./lib/games");
const { desiredLinks } = require("./link");

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

test("every registered game is a complete game project", () => {
  const ids = listGameIds();
  assert.ok(ids.length > 0, "at least one game is registered");
  for (const id of ids) {
    const game = loadGame(id);
    assert.match(gameVersion(game), /^\d+\.\d+\.\d+/);
    for (const file of ["project.godot", "export_presets.cfg", ".gutconfig.json"]) {
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
