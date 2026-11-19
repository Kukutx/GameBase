const assert = require("node:assert/strict");
const test = require("node:test");
const { hexInts, parseDocuments, parseScalar, parseSingle } = require("./lib/unity_yaml");
const { isSimplePolygon, convexHull, sanitize } = require("./lib/unity_nodes");

test("plain scalars read as numbers, text and Unity's references", () => {
  assert.equal(parseScalar("12"), 12);
  assert.equal(parseScalar("-0.5"), -0.5);
  assert.equal(parseScalar("Field"), "Field");
  assert.equal(parseScalar("'it''s'"), "it's");
  assert.equal(parseScalar('"\\u4F60\\u597D"'), "你好");
  assert.deepEqual(parseScalar("{fileID: 21300000, guid: abc, type: 3}"), { fileID: 21300000, guid: "abc", type: 3 });
});

test("64-bit file ids and hex int arrays stay exact", () => {
  assert.equal(parseScalar("6823815920935795074"), "6823815920935795074");
  assert.equal(parseScalar("0100000002000000"), "0100000002000000", "leading zero text is no number");
  assert.deepEqual(hexInts("0100000002000000"), [1, 2]);
  assert.deepEqual(hexInts(10000000), [16], "a hex array YAML read as a number");
  assert.deepEqual(hexInts(""), []);
});

test("documents keep their class, file id and body", () => {
  const text = [
    "%YAML 1.1",
    "--- !u!1 &100",
    "GameObject:",
    "  m_Name: Tool Box",
    "  m_Component:",
    "  - component: {fileID: 101}",
    "--- !u!4 &101 stripped",
    "Transform:",
    "  m_LocalPosition: {x: 1.5, y: -2, z: 0}",
  ].join("\n");
  const [object, transform] = parseDocuments(text);
  assert.equal(object.classId, 1);
  assert.equal(object.fileId, "100");
  assert.equal(object.type, "GameObject");
  assert.equal(object.data.m_Name, "Tool Box");
  assert.deepEqual(object.data.m_Component, [{ component: { fileID: 101 } }]);
  assert.equal(transform.stripped, true);
  assert.deepEqual(transform.data.m_LocalPosition, { x: 1.5, y: -2, z: 0 });
});

test("a .meta file reads as one mapping, with indentless sequences", () => {
  const meta = parseSingle([
    "fileFormatVersion: 2",
    "guid: 4f22444843b41094a8ee036c3542878b",
    "TextureImporter:",
    "  spritePixelsToUnits: 20",
    "  spriteSheet:",
    "    sprites:",
    "    - name: a_0",
    "      rect:",
    "        x: 0",
    "        y: 16",
    "    - name: a_1",
  ].join("\n"));
  assert.equal(meta.guid, "4f22444843b41094a8ee036c3542878b");
  assert.equal(meta.TextureImporter.spritePixelsToUnits, 20);
  assert.equal(meta.TextureImporter.spriteSheet.sprites.length, 2);
  assert.equal(meta.TextureImporter.spriteSheet.sprites[0].rect.y, 16);
});

test("a self-crossing collider path becomes its convex hull", () => {
  const square = [[0, 0], [10, 0], [10, 10], [0, 10]];
  assert.equal(isSimplePolygon(square), true);
  const bowtie = [[0, 0], [10, 10], [10, 0], [0, 10]];
  assert.equal(isSimplePolygon(bowtie), false);
  const hull = convexHull([...bowtie, [5, 5]]);
  assert.equal(hull.length, 4);
  assert.equal(isSimplePolygon(hull), true);
});

test("node names lose what Godot does not allow", () => {
  assert.equal(sanitize("Tree/Top:1"), "Tree_Top_1");
});
