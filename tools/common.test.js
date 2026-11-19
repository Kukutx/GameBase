const assert = require("node:assert/strict");
const test = require("node:test");
const { engineErrorLines } = require("./lib/common");

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
