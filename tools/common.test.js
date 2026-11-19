const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { engineErrorLines, godotUserDataDir, quietAddonUpdateChecks } = require("./lib/common");

test("engine errors fail a step, GUT's online version check does not", () => {
  const output = [
    "ERROR: Failed loading resource: res://game/missing.tscn.",
    "SCRIPT ERROR: Parse Error: Could not find base class \"Missing\".",
    "ERROR: [GUT] Could not get version info, response code:  403 (API rate limit exceeded)",
    "ERROR: [GUT] An error occurred requesting version data:  31.",
    "WARNING: only a warning",
  ].join("\n");
  assert.deepEqual(engineErrorLines(output), [
    "ERROR: Failed loading resource: res://game/missing.tscn.",
    "SCRIPT ERROR: Parse Error: Could not find base class \"Missing\".",
  ]);
});

test("a Godot step tells the project's addons not to ask the network for updates", { skip: process.platform !== "linux" }, () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "tiamat-gut-check-"));
  const before = process.env.XDG_DATA_HOME;
  process.env.XDG_DATA_HOME = path.join(scratch, "data");
  try {
    const project = path.join(scratch, "probe");
    fs.mkdirSync(path.join(project, "addons", "gut"), { recursive: true });
    fs.writeFileSync(path.join(project, "addons", "gut", "versions.json"), JSON.stringify({ releases: { "9.7.1": { godot_min: "4.7.0", godot_max: "4.7.99" } } }));
    fs.writeFileSync(path.join(project, "project.godot"), '[application]\n\nconfig/name="Probe: Game"\n');
    const cache = path.join(godotUserDataDir("Probe: Game"), "gut_temp_directory", "versions.json");
    assert.equal(cache, path.join(scratch, "data", "godot", "app_userdata", "Probe_ Game", "gut_temp_directory", "versions.json"));
    quietAddonUpdateChecks(project);
    const marked = JSON.parse(fs.readFileSync(cache, "utf8"));
    assert.ok(marked.releases["9.7.1"], "the versions GUT ships");
    assert.ok(Math.abs(marked.fetch_timestamp - Date.now() / 1000) < 60, "checked now");
    fs.writeFileSync(cache, JSON.stringify({ fetch_timestamp: marked.fetch_timestamp, releases: {} }));
    quietAddonUpdateChecks(project);
    assert.deepEqual(JSON.parse(fs.readFileSync(cache, "utf8")).releases, {}, "a fresh mark stays, a real fetch's included");
    fs.mkdirSync(path.join(project, "addons", "dialogue_manager"), { recursive: true });
    fs.writeFileSync(path.join(project, "addons", "dialogue_manager", "plugin.cfg"), "[plugin]\n");
    const dialogue = path.join(godotUserDataDir("Probe: Game"), "dialogue_manager_user_config.json");
    fs.writeFileSync(dialogue, JSON.stringify({ recent_files: ["res://a.dialogue"] }));
    quietAddonUpdateChecks(project);
    assert.deepEqual(JSON.parse(fs.readFileSync(dialogue, "utf8")), { recent_files: ["res://a.dialogue"], check_for_updates: false }, "Dialogue Manager's check is off, its other settings stay");
    fs.rmSync(path.join(project, "addons"), { recursive: true });
    fs.rmSync(cache);
    fs.rmSync(dialogue);
    quietAddonUpdateChecks(project);
    assert.equal(fs.existsSync(cache), false, "a project without GUT is left alone");
    assert.equal(fs.existsSync(dialogue), false, "and one without Dialogue Manager");
  } finally {
    if (before === undefined) delete process.env.XDG_DATA_HOME;
    else process.env.XDG_DATA_HOME = before;
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});
