const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { rootPath } = require("./lib/common");
const { createModule, formatManifest, moduleClass } = require("./new_module");

// A foundation of its own: the repository's tiamat.json and no module files.
function scratchFoundation(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "tiamat-new-module-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, "tiamat", "modules"), { recursive: true });
  fs.copyFileSync(rootPath("tiamat", "tiamat.json"), path.join(root, "tiamat", "tiamat.json"));
  return root;
}

test("tiamat.json is written as it is kept, so a new module changes only its own lines", () => {
  const text = fs.readFileSync(rootPath("tiamat", "tiamat.json"), "utf8");
  assert.equal(`${formatManifest(JSON.parse(text))}\n`, text);
  assert.equal(moduleClass("npc_social"), "NpcSocialModule");
});

test("a new module is laid out as docs/MODULES.md says and declared in order", (t) => {
  const root = scratchFoundation(t);
  const before = fs.readFileSync(path.join(root, "tiamat", "tiamat.json"), "utf8");
  createModule({ id: "fishing", requires: ["items", "items"], root });
  const directory = path.join(root, "tiamat", "modules", "fishing");
  const script = fs.readFileSync(path.join(directory, "fishing_module.gd"), "utf8");
  assert.match(script, /^class_name FishingModule\nextends GameModule\n/);
  assert.match(script, /^func install\(\) -> void:$/m);
  assert.match(fs.readFileSync(path.join(directory, "test", "test_fishing_module.gd"), "utf8"), /assert_has\(GameModules\.get_installed\(\), "FishingModule"\)/);
  assert.match(fs.readFileSync(path.join(directory, "i18n", "fishing.zh_CN.po"), "utf8"), /"Project-Id-Version: Tiamat modules\/fishing\\n"/);
  const after = fs.readFileSync(path.join(root, "tiamat", "tiamat.json"), "utf8");
  const manifest = JSON.parse(after);
  assert.deepEqual(manifest.modules.fishing, { requires: ["items"] });
  assert.deepEqual(Object.keys(manifest.modules), Object.keys(manifest.modules).sort(), "the modules stay in the order of their ids");
  const added = after.split("\n").filter((line) => !before.split("\n").includes(line));
  assert.deepEqual(added, ['    "fishing": {', '      "requires": ["items"]'], "only the new module's lines are new");
});

test("a module is refused a bad id, a taken one or an unknown requirement", (t) => {
  const root = scratchFoundation(t);
  assert.throws(() => createModule({ id: "Fishing", root }), /Invalid module id 'Fishing'/);
  assert.throws(() => createModule({ id: "fish-ing", root }), /Invalid module id/);
  assert.throws(() => createModule({ id: "skills", root }), /Module skills already exists/);
  assert.throws(() => createModule({ id: "fishing", requires: ["boats"], root }), /requires boats, which is no module/);
  assert.equal(fs.existsSync(path.join(root, "tiamat", "modules", "fishing")), false, "a refused module writes nothing");
});
