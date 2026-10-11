const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { allowed, checkLayers, layerOf, resLayer, stripComments } = require("./check_layers");

function fixture(files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "layers-"));
  for (const [file, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(path.join(root, file), typeof content === "string" ? content : JSON.stringify(content));
  }
  return root;
}

const FOUNDATION = { addons: ["gut"], modules: { items: { requires: [] }, fishing: { requires: ["items"] } } };
const PROJECT = [
  "[autoload]",
  "",
  'ContentDB="*res://game/content/db.gd"',
  'Inventory="*res://gamebase/modules/items/inventory.gd"',
  "",
].join("\n");

test("layers follow the directory a file lives in", () => {
  assert.equal(layerOf("gamebase/core/save/a.gd"), "core");
  assert.equal(layerOf("gamebase/modules/items/a.gd"), "module:items");
  assert.equal(layerOf("games/farm1/game/a.gd"), "game:farm1");
  assert.equal(resLayer("game/a.gd", "farm1"), "game:farm1");
  assert.equal(resLayer("game/a.gd", null), "game");
  assert.equal(resLayer("addons/gut/plugin.cfg", "farm1"), "addon:gut");
  assert.ok(allowed("module:items", "core"));
  assert.ok(allowed("module:items", "module:lifesim"));
  assert.ok(!allowed("core", "module:items"));
  assert.ok(!allowed("core", "addon:gut"));
  assert.ok(!allowed("module:items", "game"));
  assert.ok(allowed("game:farm1", "module:items"));
});

test("comments are ignored but strings containing # are kept", () => {
  assert.equal(stripComments('var a := "x#y" # Inventory'), 'var a := "x#y" ');
});

test("the real repository has no layer violation", () => {
  assert.deepEqual(checkLayers(), []);
});

test("core using a module, a game path or a content id is reported", () => {
  const root = fixture({
    "gamebase/gamebase.json": FOUNDATION,
    "games/one/game.json": { id: "one", modules: ["items"] },
    "games/one/project.godot": PROJECT,
    "gamebase/core/content/registry.gd": "class_name Registry\nextends Node\nfunc get_entry() -> void:\n\tpass\n",
    "games/one/game/content/db.gd": "extends Registry\nfunc get_item() -> void:\n\tpass\n",
    "gamebase/modules/items/inventory.gd": "extends Node\n",
    "games/one/game/data/berry.tres": '[resource]\nid = &"berry"\n',
    "gamebase/core/a.gd": 'extends Node\nfunc f() -> void:\n\tInventory.clear()\n\tContentDB.get_entry()\n\tload("res://game/x.tres")\n\tprint(&"berry")\n',
    "gamebase/modules/items/b.gd": "extends Node\nfunc f() -> void:\n\tContentDB.get_item()\n\tContentDB.missing()\n",
  });
  const problems = checkLayers(root);
  assert.ok(problems.includes("gamebase/core/a.gd (core) must not use Inventory"));
  assert.ok(problems.includes("gamebase/core/a.gd (core) must not use path:game/x.tres"));
  assert.ok(problems.includes("gamebase/core/a.gd (core) must not use literal:berry"));
  assert.ok(problems.some((p) => p.includes("calls ContentDB.missing()")));
  assert.ok(!problems.some((p) => p.includes("ContentDB.get_item") || p.includes("use ContentDB")));
});

test("a module using a module or addon it does not declare is reported", () => {
  const root = fixture({
    "gamebase/gamebase.json": { modules: { items: {}, fishing: { requires: [] }, ghost: {} } },
    "games/one/game.json": { id: "one", modules: [] },
    "games/one/project.godot": PROJECT,
    "gamebase/modules/items/inventory.gd": "extends Node\n",
    "gamebase/modules/fishing/rod.gd": 'extends Node\nfunc f() -> void:\n\tInventory.clear()\n\tload("res://addons/gut/gut.gd")\n',
    "gamebase/modules/combat/sword.gd": "extends Node\n",
    "addons/gut/plugin.cfg": "",
  });
  const problems = checkLayers(root);
  assert.ok(problems.some((p) => p.startsWith("gamebase/modules/fishing uses module items")));
  assert.ok(problems.some((p) => p.startsWith("gamebase/modules/fishing uses addon gut")));
  assert.ok(problems.includes('gamebase/modules/combat is not listed under "modules" in gamebase/gamebase.json'));
  assert.ok(problems.includes("gamebase/gamebase.json lists module ghost, which does not exist"));
});

test("a game uses only the modules and addons its game.json lists", () => {
  const root = fixture({
    "gamebase/gamebase.json": FOUNDATION,
    "addons/gut/plugin.cfg": "",
    "addons/dialogue/plugin.cfg": "",
    "games/one/game.json": { id: "one", modules: ["fishing"] },
    "games/one/project.godot": [
      "[autoload]",
      'Inventory="*res://gamebase/modules/items/inventory.gd"',
      'Dialogue="*res://addons/dialogue/manager.gd"',
      "[editor_plugins]",
      'enabled=PackedStringArray("res://addons/gut/plugin.cfg")',
    ].join("\n"),
    "gamebase/modules/items/inventory.gd": "extends Node\n",
    "gamebase/modules/fishing/rod.gd": "class_name Rod\nextends Node\n",
    "games/one/game/player.gd": "extends Node\nfunc f() -> void:\n\tInventory.clear()\n\tRod.new()\n",
  });
  const problems = checkLayers(root);
  assert.ok(problems.includes("games/one/game.json: module fishing requires items; list it in modules"));
  assert.ok(problems.some((p) => p.startsWith("games/one/game/player.gd uses Inventory from module items")));
  assert.ok(problems.some((p) => p.startsWith("games/one/project.godot uses path:addons/dialogue/manager.gd from addon dialogue")));
  assert.ok(!problems.some((p) => p.includes("Rod") || p.includes("addons/gut")));
});
