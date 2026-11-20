const assert = require("node:assert/strict");
const test = require("node:test");
const { contentScripts, exportedFields, formatValue, plural, renderEntry } = require("./new_content");

const SCRIPTS = [
  { resPath: "res://tiamat/core/content/content_entry.gd", linked: true, text: "class_name ContentEntry\nextends Resource\n\n@export var id: StringName\n" },
  {
    resPath: "res://tiamat/modules/items/items/item_data.gd",
    linked: false,
    text: 'class_name ItemData\nextends ContentEntry\n\nconst KIND := &"item"\n\n@export var display_name := ""\n@export_range(0, 999) var price := 0\n@export var tags: PackedStringArray = PackedStringArray()\n',
  },
  { resPath: "res://game/data/seed_data.gd", linked: true, text: 'class_name SeedData\nextends ItemData\n\n@export var crop_id: StringName\n@export_multiline var note := ""\n' },
  { resPath: "res://game/ui/hud.gd", linked: true, text: "class_name Hud\nextends CanvasLayer\n" },
];

test("the content scripts are those that extend ContentEntry, with the kind each declares or inherits", () => {
  const scripts = contentScripts(SCRIPTS);
  assert.deepEqual([...scripts.keys()].sort(), ["ItemData", "SeedData"]);
  assert.equal(scripts.get("ItemData").ownKind, "item");
  assert.equal(scripts.get("SeedData").ownKind, null);
  assert.equal(scripts.get("SeedData").kind, "item", "a class that extends one inherits its kind");
  assert.equal(scripts.get("ItemData").linked, false);
});

test("a class exports its own fields and those of the classes it extends, typed", () => {
  const scripts = contentScripts(SCRIPTS);
  const fields = exportedFields(scripts, scripts.get("SeedData"));
  assert.equal(fields.get("crop_id"), "StringName");
  assert.equal(fields.get("note"), "String", "typed from its default");
  assert.equal(fields.get("display_name"), "String");
  assert.equal(fields.get("price"), "int");
  assert.equal(fields.get("tags"), "PackedStringArray");
  assert.equal(fields.get("id"), "StringName");
});

test("a value is written as its field's type asks", () => {
  assert.equal(formatValue("fish_caught", "StringName", "flag"), '&"fish_caught"');
  assert.equal(formatValue('&"fish_caught"', "StringName", "flag"), '&"fish_caught"');
  assert.equal(formatValue('Master "Angler"', "String", "display_name"), '"Master \\"Angler\\""');
  assert.equal(formatValue("42", "int", "goal"), "42");
  assert.equal(formatValue('PackedStringArray("a", "b")', "PackedStringArray", "tags"), 'PackedStringArray("a", "b")');
  assert.equal(formatValue("true", "", "hidden"), "true");
  assert.equal(formatValue("plain words", "", "label"), '"plain words"');
  assert.throws(() => formatValue("many", "int", "goal"), /Give goal \(int\) as Godot writes it/);
});

test("a new entry names its script and lists its fields, the id first", () => {
  const scripts = contentScripts(SCRIPTS);
  const text = renderEntry(scripts.get("SeedData"), new Map([["id", '&"turnip_seed"'], ["crop_id", '&"turnip"']]));
  assert.equal(text, `[gd_resource type="Resource" script_class="SeedData" format=3]

[ext_resource type="Script" path="res://game/data/seed_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"turnip_seed"
crop_id = &"turnip"
`);
});

test("a kind's folder is its plural", () => {
  assert.deepEqual(["achievement", "audio_cue", "battle_map", "box", "story", "day"].map(plural), ["achievements", "audio_cues", "battle_maps", "boxes", "stories", "days"]);
});
