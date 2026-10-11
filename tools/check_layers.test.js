const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { allowed, checkLayers, layerOf, stripComments } = require("./check_layers");

function fixture(files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "layers-"));
  for (const [file, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(path.join(root, file), content);
  }
  return root;
}

const PROJECT = [
  "[autoload]",
  "",
  'ContentDB="*res://game/content/db.gd"',
  'Inventory="*res://gamebase/modules/items/inventory.gd"',
  "",
].join("\n");

test("layers follow the directory a script lives in", () => {
  assert.equal(layerOf("gamebase/core/save/a.gd"), "core");
  assert.equal(layerOf("gamebase/modules/items/a.gd"), "module:items");
  assert.equal(layerOf("game/a.gd"), "game");
  assert.ok(allowed("module:items", "core"));
  assert.ok(allowed("module:items", "module:lifesim"));
  assert.ok(!allowed("core", "module:items"));
  assert.ok(!allowed("module:items", "game"));
  assert.ok(allowed("game", "module:items"));
});

test("comments are ignored but strings containing # are kept", () => {
  assert.equal(stripComments('var a := "x#y" # Inventory'), 'var a := "x#y" ');
});

test("the real project has no unlisted layer violation", () => {
  assert.deepEqual(checkLayers(), []);
});

test("core using a module, a game path or a content id is reported", () => {
  const root = fixture({
    "project.godot": PROJECT,
    "gamebase/core/content/registry.gd": "class_name Registry\nextends Node\nfunc get_entry() -> void:\n\tpass\n",
    "game/content/db.gd": "extends Registry\nfunc get_item() -> void:\n\tpass\n",
    "gamebase/modules/items/inventory.gd": "extends Node\n",
    "game/data/berry.tres": '[resource]\nid = &"berry"\n',
    "gamebase/core/a.gd": 'extends Node\nfunc f() -> void:\n\tInventory.clear()\n\tContentDB.get_entry()\n\tload("res://game/x.tres")\n\tprint(&"berry")\n',
    "gamebase/modules/items/b.gd": "extends Node\nfunc f() -> void:\n\tContentDB.get_item()\n\tContentDB.missing()\n",
  });
  const problems = checkLayers(root, path.join(root, "baseline.json"));
  assert.ok(problems.includes("gamebase/core/a.gd (core) must not use Inventory"));
  assert.ok(problems.includes("gamebase/core/a.gd (core) must not use path:game/x.tres"));
  assert.ok(problems.includes("gamebase/core/a.gd (core) must not use literal:berry"));
  assert.ok(problems.some((p) => p.includes("calls ContentDB.missing()")));
  assert.ok(!problems.some((p) => p.includes("ContentDB.get_item") || p.includes("use ContentDB")));
});

test("baseline entries silence known violations and must not go stale", () => {
  const root = fixture({
    "project.godot": PROJECT,
    "gamebase/modules/items/inventory.gd": "extends Node\n",
    "gamebase/core/a.gd": "extends Node\nfunc f() -> void:\n\tInventory.clear()\n",
    "baseline.json": JSON.stringify({ entries: { "gamebase/core/a.gd": { uses: ["Inventory"] }, "gamebase/core/gone.gd": { uses: ["X"] } } }),
  });
  assert.deepEqual(checkLayers(root, path.join(root, "baseline.json")), [
    "tools/layer_baseline.json lists gamebase/core/gone.gd -> X, which no longer occurs; remove it",
  ]);
});
