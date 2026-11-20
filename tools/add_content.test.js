const assert = require("node:assert/strict");
const test = require("node:test");
const { addToPack, contentClasses, listedPaths } = require("./add_content");

const PACK = `[gd_resource type="Resource" script_class="ContentPack" load_steps=3 format=3]

[ext_resource type="Script" path="res://tiamat/core/content/content_pack.gd" id="1_pack"]
[ext_resource type="Resource" path="res://game/data/start_location.tres" id="2_start"]

[resource]
script = ExtResource("1_pack")
entries = [ExtResource("2_start")]
`;

test("a pack lists a new file last and counts its load steps again", () => {
  const text = addToPack(PACK, ["res://game/data/records/battles_won.tres", "res://game/data/start_location.tres"], "res://game/data");
  assert.equal(text, `[gd_resource type="Resource" script_class="ContentPack" load_steps=4 format=3]

[ext_resource type="Script" path="res://tiamat/core/content/content_pack.gd" id="1_pack"]
[ext_resource type="Resource" path="res://game/data/start_location.tres" id="2_start"]
[ext_resource type="Resource" path="res://game/data/records/battles_won.tres" id="records_battles_won"]

[resource]
script = ExtResource("1_pack")
entries = [ExtResource("2_start"), ExtResource("records_battles_won")]
`);
  assert.deepEqual([...listedPaths(text)], ["res://game/data/start_location.tres", "res://game/data/records/battles_won.tres"]);
  assert.equal(addToPack(text, ["res://game/data/records/battles_won.tres"], "res://game/data"), text, "a file it lists stays as it is");
});

test("a pack without load steps or entries takes a file too, under an id of its own", () => {
  const pack = `[gd_resource type="Resource" script_class="ContentPack" format=3]

[ext_resource type="Script" path="res://tiamat/core/content/content_pack.gd" id="records_a"]

[resource]
script = ExtResource("records_a")
entries = []
`;
  const text = addToPack(pack, ["res://game/data/records/a.tres"], "res://game/data");
  assert.match(text, /^\[gd_resource type="Resource" script_class="ContentPack" format=3\]\n/);
  assert.match(text, /\[ext_resource type="Resource" path="res:\/\/game\/data\/records\/a.tres" id="records_a_2"\]\n\n\[resource\]/);
  assert.match(text, /^entries = \[ExtResource\("records_a_2"\)\]$/m);
});

test("the content classes are those that extend ContentEntry, directly or not", () => {
  const classes = contentClasses([
    "class_name ItemData\nextends ContentEntry\n",
    "class_name SeedData\nextends ItemData\n",
    "class_name Helper\nextends RefCounted\n",
    "extends ContentEntry\n",
  ]);
  assert.deepEqual([...classes].sort(), ["ItemData", "SeedData"]);
});
