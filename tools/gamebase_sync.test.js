const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { check, install, readManifest, resolveModules, shippedFiles } = require("./gamebase_sync");

const ROOT = path.resolve(__dirname, "..");

function tree(files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "gamebase-sync-"));
  for (const [file, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(path.join(root, file), content);
  }
  return root;
}

function foundation(version, extra = {}) {
  return tree({
    "gamebase/gamebase.json": JSON.stringify({ name: "gamebase", version, include: ["gamebase/", "tools/"], exclude: ["tools/local.json"] }),
    "gamebase/core/a.gd": "extends Node\n",
    "tools/check.js": "// v1\n",
    "tools/local.json": "{}",
    "game/own.gd": "# never shipped\n",
    ...extra,
  });
}

test("this repository ships the foundation, its addons, the build pipeline and the engine baseline, but no game files", () => {
  const files = shippedFiles(ROOT, readManifest(ROOT));
  assert.ok(files.includes("gamebase/core/content/content_registry.gd"));
  assert.ok(files.includes("addons/gut/plugin.cfg"));
  assert.ok(files.includes("tools/gamebase_sync.js"));
  assert.ok(!files.some((file) => file.startsWith("game/") || file.startsWith("test/")));
  assert.ok(files.includes("tools/check_layers.js") && files.includes("tools/validate.js"));
  assert.ok(files.includes(".github/workflows/ci.yml") && files.includes("licenses/GODOT_LICENSE.txt"));
  assert.ok(!files.includes("tools/layer_baseline.json") && !files.includes("tools/new_game.js"));
  assert.ok(!files.some((file) => file.includes("node_modules/")));
  assert.ok(!files.some((file) => file.startsWith("gamebase/templates/")));
});

test("module requirements resolve transitively and reject unknown modules", () => {
  const manifest = { modules: { a: { requires: ["b"] }, b: { requires: ["c"] }, c: {}, d: {} } };
  assert.deepEqual(resolveModules(manifest, ["a"]), ["a", "b", "c"]);
  assert.deepEqual(resolveModules(manifest, []), []);
  assert.throws(() => resolveModules(manifest, ["x"]), /unknown GameBase module 'x'/);
});

test("install ships only the selected modules and keeps the selection on upgrade", () => {
  const modular = (version) =>
    tree({
      "gamebase/gamebase.json": JSON.stringify({
        name: "gamebase",
        version,
        include: ["gamebase/"],
        modules: { fishing: { requires: ["items"] }, items: {}, combat: {} },
      }),
      "gamebase/core/a.gd": "extends Node\n",
      "gamebase/modules/fishing/f.gd": "extends Node\n",
      "gamebase/modules/items/i.gd": "extends Node\n",
      "gamebase/modules/combat/c.gd": "extends Node\n",
    });
  const project = tree({});
  assert.deepEqual(install({ from: modular("1.0.0"), project, modules: "fishing" }).modules, ["fishing", "items"]);
  assert.ok(fs.existsSync(path.join(project, "gamebase/modules/items/i.gd")));
  assert.ok(!fs.existsSync(path.join(project, "gamebase/modules/combat/c.gd")));
  assert.deepEqual(install({ from: modular("1.1.0"), project }).modules, ["fishing", "items"]);
  assert.deepEqual(install({ from: modular("1.1.0"), project, modules: "none" }).modules, []);
  assert.ok(!fs.existsSync(path.join(project, "gamebase/modules/fishing/f.gd")));
  assert.ok(fs.existsSync(path.join(project, "gamebase/core/a.gd")));
});

test("install copies the listed files, writes the lock and keeps game files", () => {
  const source = foundation("1.0.0");
  const project = tree({ "game/mine.gd": "# game\n" });
  const result = install({ from: source, project });
  assert.equal(result.installed, 3);
  assert.equal(fs.readFileSync(path.join(project, "game/mine.gd"), "utf8"), "# game\n");
  assert.ok(!fs.existsSync(path.join(project, "game/own.gd")));
  assert.ok(!fs.existsSync(path.join(project, "tools/local.json")));
  const lock = JSON.parse(fs.readFileSync(path.join(project, "gamebase.lock.json"), "utf8"));
  assert.equal(lock.version, "1.0.0");
  assert.deepEqual(Object.keys(lock.files), ["gamebase/core/a.gd", "gamebase/gamebase.json", "tools/check.js"]);
  assert.deepEqual(check({ project }).modified, []);
});

test("an upgrade removes files the new version dropped", () => {
  const project = tree({});
  install({ from: foundation("1.0.0", { "gamebase/core/old.gd": "extends Node\n" }), project });
  assert.ok(fs.existsSync(path.join(project, "gamebase/core/old.gd")));
  const result = install({ from: foundation("1.1.0"), project });
  assert.equal(result.previous, "1.0.0");
  assert.equal(result.removed, 1);
  assert.ok(!fs.existsSync(path.join(project, "gamebase/core/old.gd")));
});

test("local edits to installed files are reported and block an upgrade without --force", () => {
  const project = tree({});
  install({ from: foundation("1.0.0"), project });
  fs.writeFileSync(path.join(project, "tools/check.js"), "// patched in the game\n");
  assert.deepEqual(check({ project }).modified, ["tools/check.js"]);
  assert.throws(() => install({ from: foundation("1.1.0"), project }), /make the change in GameBase/);
  install({ from: foundation("1.1.0"), project, force: true });
  assert.deepEqual(check({ project }).modified, []);
});

test("a directory without the manifest is rejected", () => {
  assert.throws(() => install({ from: tree({}), project: tree({}) }), /not a GameBase checkout/);
});
