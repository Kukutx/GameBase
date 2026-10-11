const assert = require("node:assert/strict");
const test = require("node:test");
const { checkCode, checkScript, MAX_LINES, MAX_TEST_LINES } = require("./check_code");

test("the repository's scripts pass the guardrails", () => {
  assert.deepEqual(checkCode(), []);
});

test("a script longer than the limit is reported, a test has more room", () => {
  const long = "var x := 1\n".repeat(MAX_LINES + 1);
  assert.match(checkScript("gamebase/core/a.gd", long).join("\n"), /has 501 lines, more than 500/);
  assert.deepEqual(checkScript("gamebase/core/test/test_a.gd", long), []);
  assert.match(checkScript("games/farm1/test/unit/test_a.gd", "pass\n".repeat(MAX_TEST_LINES + 1)).join("\n"), /more than 1000/);
});

test("resources never come from user:// nor are saved at runtime", () => {
  const problems = checkScript("gamebase/core/a.gd", [
    'var mod := load("user://mods/mod.tres")',
    'var data := ResourceLoader.load("user://save.res")',
    "ResourceSaver.save(resource, path)",
    'var text := FileAccess.get_file_as_string("user://saves/slot_1.json") # load("user://x.tres") in a comment is fine',
    'var preview := ResourceLoader.load_threaded_request(',
    '\tOS.get_user_data_dir().path_join("shot.res"))',
  ].join("\n"));
  assert.equal(problems.length, 4);
  assert.match(problems[0], /a\.gd:1 loads a resource from user:\/\//);
  assert.match(problems[1], /a\.gd:2 loads a resource from user:\/\//);
  assert.match(problems[2], /a\.gd:5 loads a resource from user:\/\//, "a call broken across lines");
  assert.match(problems[3], /a\.gd:3 saves a resource at runtime/);
  assert.deepEqual(checkScript("gamebase/core/test/test_a.gd", "ResourceSaver.save(scene, path)\n"), [], "a test may write a fixture scene");
});

test("a user:// path held in a name is still a user:// path", () => {
  const source = [
    'const MODS_DIR := "user://mods"',
    "var _cache: String = OS.get_user_data_dir()",
    "func read(id: String) -> Resource:",
    "\treturn load(MODS_DIR.path_join(id))",
    "func read_cached() -> Resource:",
    "\treturn ResourceLoader.load(_cache + \"/a.tres\")",
    "func shipped() -> Resource:",
    '\treturn load("res://content/a.tres")',
    "func reload(scene: Node) -> void:",
    "\tscene.load_state(MODS_DIR)",
  ].join("\n");
  const problems = checkScript("gamebase/core/a.gd", source);
  assert.deepEqual(problems.map((problem) => problem.match(/a\.gd:(\d+)/)[1]), ["4", "6"]);
});

test("player data is never parsed by what can build resources and objects", () => {
  const source = "var file := ConfigFile.new()\nvar value = str_to_var(text)\nvar more = bytes_to_var_with_objects(bytes)\nvar safe = bytes_to_var(bytes)\n";
  const problems = checkScript("gamebase/core/a.gd", source);
  assert.equal(problems.length, 3);
  assert.match(problems[0], /a\.gd:1 parses text that can name resources and objects/);
  assert.deepEqual(checkScript("gamebase/core/test/test_a.gd", source), [], "a test may read a fixture");
});

test("only the input lock pauses the world", () => {
  const source = [
    "get_tree().paused = true",
    "if get_tree().paused == false:",
    "\tclock.paused = true",
    "tree.paused = true",
    "scene_tree.paused = false",
    "Engine.get_main_loop().paused = true",
    "(Engine.get_main_loop() as SceneTree).paused = true",
    "get_tree().set_pause(true)",
    'get_tree().set("paused", true)',
    "get_tree().set_deferred(&\"paused\", true)",
  ].join("\n");
  assert.deepEqual(checkScript("gamebase/core/input/input_lock.gd", source), []);
  const problems = checkScript("gamebase/modules/items/shop/shop_menu.gd", source);
  assert.deepEqual(problems.map((problem) => problem.match(/shop_menu\.gd:(\d+)/)[1]), ["1", "4", "5", "6", "7", "8", "9", "10"]);
  assert.match(problems[0], /sets SceneTree\.paused; take a lock with InputLock/);
});
