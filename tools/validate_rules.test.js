const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");
const {
  CLI_FLAGS,
  REQUIRED_AGENT_PATH_ROUTES,
  REQUIRED_BOUNDARY_PRESSURE_TESTS,
  REQUIRED_CORE_PRESSURE_TESTS,
  REQUIRED_PRESSURE_TESTS,
  REQUIRED_SKILL_ROUTING_TESTS,
  REQUIRED_VERIFICATION_SEMANTICS_TESTS,
  collectInstructionFootprint,
  extractAgentsReferences,
  extractPressureTestScenarios,
  extractRepositoryReferences,
  findBrokenRepositoryReferences,
  findNonEnglishLines,
  findRulePathScopeMismatches,
  findUnreachableMarkdownPaths,
  findUnsupportedCliFlags,
  hasAbsoluteLocalPath,
  hasAutomationPolicyRouting,
  hasUnconditionalAgentPreload,
  parseAgentPathRoutes,
  parseFrontMatterData,
  skillDirectoryName,
  validateStructure,
} = require("./validate_rules");

const ROOT = path.resolve(__dirname, "..");
const ENTRY = path.join(__dirname, "validate_rules.js");

test("the core pressure tests are fixed at A01 to A36", () => {
  assert.equal(REQUIRED_CORE_PRESSURE_TESTS.length, 36);
  assert.equal(REQUIRED_CORE_PRESSURE_TESTS[0], "A01");
  assert.equal(REQUIRED_CORE_PRESSURE_TESTS.at(-1), "A36");
});

test("the boundary, skill-routing and verification-semantics scenarios are part of the static retention gate", () => {
  assert.deepEqual(REQUIRED_BOUNDARY_PRESSURE_TESTS, [
    "G05", "G06", "G08", "G09", "G10", "G11", "G12", "G13", "G14", "G15", "G16", "G17", "G18", "G19", "G20",
  ]);
  assert.deepEqual(REQUIRED_SKILL_ROUTING_TESTS, ["H01", "H02", "H03", "H04", "H05", "H06", "H07"]);
  assert.deepEqual(REQUIRED_VERIFICATION_SEMANTICS_TESTS, ["I01", "I02", "I03", "I04", "I05", "I06"]);
  assert.deepEqual(REQUIRED_PRESSURE_TESTS, [
    ...REQUIRED_CORE_PRESSURE_TESTS,
    ...REQUIRED_BOUNDARY_PRESSURE_TESTS,
    ...REQUIRED_SKILL_ROUTING_TESTS,
    ...REQUIRED_VERIFICATION_SEMANTICS_TESTS,
  ]);
});

test("an unsupported CLI flag is rejected instead of passing silently", () => {
  assert.deepEqual(Object.values(CLI_FLAGS).sort(), ["--report", "--strict"]);
  assert.deepEqual(findUnsupportedCliFlags(["--strict"]), []);
  assert.deepEqual(findUnsupportedCliFlags(["--report"]), []);
  assert.deepEqual(findUnsupportedCliFlags(["--strict", "--report"]), []);
  assert.deepEqual(findUnsupportedCliFlags(["--fix"]), ["--fix"]);
  assert.deepEqual(findUnsupportedCliFlags(["note", "--unknown"]), ["--unknown"]);
});

test("asking for help does not start the check, and an unimplemented flag fails", () => {
  for (const flag of ["--help", "-h"]) {
    const result = spawnSync(process.execPath, [ENTRY, flag], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Usage:/);
    assert.match(result.stdout, /--report/);
    assert.doesNotMatch(result.stdout, /check passed|check failed/);
  }
  const unsupported = spawnSync(process.execPath, [ENTRY, "--fix"], { encoding: "utf8" });
  assert.equal(unsupported.status, 1);
  assert.match(unsupported.stderr, /does not support: --fix/);
});

test("the instruction footprint reports reproducible source bytes and does not pose as a token count", () => {
  const report = collectInstructionFootprint();
  assert.equal(report.unit, "source_bytes");
  assert.match(report.note, /not tokenizer counts/i);
  assert.ok(report.agentEntry > 0);
  assert.ok(report.typicalPathRoutes["gdscript.md"] > report.agentEntry);
  assert.ok(report.conditionalCore.project > 0);
  assert.ok(report.skills["ui-design"].root > 0);
  assert.ok(report.prompts.index > 0);
  assert.ok(report.storedAgentsMarkdownTotal > report.conditionalCore.project);
});

test("scenario ids of every group are extracted, and duplicates are kept for the validator to report", () => {
  const content = [
    "## A01: read-only analysis",
    "## A02: explicit analysis",
    "## B01: schema synchronization",
    "## B01: a duplicated scenario",
    "## A17a: a reserved capability",
    "## F01: quality of the base",
    "## G01: a complete goal",
    "## G01: a duplicated capability scenario",
    "### G02: an ordinary sub-heading",
    "## Another heading",
  ].join("\n");

  assert.deepEqual(extractPressureTestScenarios(content), [
    "A01", "A02", "B01", "B01", "A17a", "F01", "G01", "G01",
  ]);
});

test("front matter rejects a plain value with a colon, a duplicated key and a non-string field", () => {
  const description = "Sync a source change across 2+ boundaries: data, saves and tests";
  const invalidColon = parseFrontMatterData([
    "---",
    "name: content-authoring",
    `description: ${description}`,
    "---",
  ].join("\n"));
  assert.ok(invalidColon.problems.length > 0);
  assert.equal(invalidColon.fields, null);

  const validQuoted = parseFrontMatterData([
    "---",
    "name: content-authoring",
    `description: "${description}"`,
    "---",
  ].join("\n"));
  assert.deepEqual(validQuoted.problems, []);
  assert.equal(validQuoted.fields.get("description"), description);

  const singleQuoted = parseFrontMatterData("---\npath: 'game/**/*.gd, test/**/*.gd'\n---\n");
  assert.deepEqual(singleQuoted.problems, []);
  assert.equal(singleQuoted.fields.get("path"), "game/**/*.gd, test/**/*.gd");

  const duplicate = parseFrontMatterData([
    "---",
    "name: content-authoring",
    "name: duplicate",
    'description: "valid"',
    "---",
  ].join("\n"));
  assert.ok(duplicate.problems.some((problem) => problem.includes("duplicated")));

  const nonString = parseFrontMatterData([
    "---",
    "name: content-authoring",
    "description: 42",
    "---",
  ].join("\n"));
  assert.ok(nonString.problems.some((problem) => problem.includes("must be a string")));

  const unquotedGlob = parseFrontMatterData("---\npath: **/*.gd\n---\n");
  assert.ok(unquotedGlob.problems.some((problem) => problem.includes("quote the value")));

  assert.deepEqual(parseFrontMatterData("# No front matter\n").problems, ["missing YAML front matter"]);
  assert.deepEqual(
    parseFrontMatterData("---\nname: broken\n").problems,
    ["malformed YAML front matter (no closing marker)"],
  );
});

test("only verifiable .agents references are extracted, and a missing one is reported", () => {
  const content = [
    "Read `.agents/rules/project.md`.",
    "Read by path `.agents/rules/*.md`.",
    "The template directory is `.agents/skills/<name>/`.",
  ].join("\n");

  assert.deepEqual(extractAgentsReferences(content), [".agents/rules/project.md"]);

  const missing = findBrokenRepositoryReferences(
    "Read `.agents/rules/__audit_missing_backtick__.md`.",
    "AGENTS.md",
    () => false,
  );
  assert.equal(missing.length, 1);
  assert.equal(missing[0].reason, "missing");
  assert.equal(missing[0].repoPath, ".agents/rules/__audit_missing_backtick__.md");
});

test("a valid relative Markdown link across directories resolves to its repository target", () => {
  const content = "Required boundary: [read](../../rules/project.md#P0)";
  const refs = extractRepositoryReferences(content, ".agents/skills/ui-design/SKILL.md");
  assert.deepEqual(refs, [{
    rawTarget: "../../rules/project.md#P0",
    repoPath: ".agents/rules/project.md",
    escapesRepository: false,
  }]);
  assert.deepEqual(
    findBrokenRepositoryReferences(
      content,
      ".agents/skills/ui-design/SKILL.md",
      (repoPath) => repoPath === ".agents/rules/project.md",
    ),
    [],
  );
});

test("a missing relative Markdown link across directories fails", () => {
  const problems = findBrokenRepositoryReferences(
    "Required boundary: [read](../../rules/__audit_missing__.md)",
    ".agents/skills/ui-design/SKILL.md",
    () => false,
  );
  assert.equal(problems.length, 1);
  assert.equal(problems[0].reason, "missing");
  assert.equal(problems[0].repoPath, ".agents/rules/__audit_missing__.md");
});

test("an inline Markdown destination supports parentheses, percent encoding and escaped parentheses", () => {
  const cases = [
    ["[read](../../rules/file(name).md)", ".agents/rules/file(name).md"],
    ["[read](../../rules/file%20name.md)", ".agents/rules/file name.md"],
    ["[read](../../rules/file\\(name\\).md)", ".agents/rules/file(name).md"],
    ["[read](<../../rules/file name.md>)", ".agents/rules/file name.md"],
    ["[outer [inner]](../../rules/project.md)", ".agents/rules/project.md"],
  ];

  for (const [content, expectedPath] of cases) {
    const refs = extractRepositoryReferences(content, ".agents/skills/ui-design/SKILL.md");
    assert.equal(refs.length, 1, content);
    assert.equal(refs[0].repoPath, expectedPath, content);
  }
});

test("a fragment follows the anchors GitHub renders, and a heading that does not exist is rejected", () => {
  const target = [
    "# Top",
    "## Default evolution strategy and language",
    "## Hello, World!",
    "## Repeat",
    "## Repeat",
    "## A--B",
    "## Foo",
    "## Foo",
    "## Foo-1",
    "## P0 — safety, sources of truth",
    "Setext Heading",
    "--------------",
  ].join("\n");
  const exists = () => true;
  const readText = () => target;
  const from = ".agents/skills/ui-design/SKILL.md";
  const broken = (content, current = from) => findBrokenRepositoryReferences(content, current, exists, readText);

  assert.deepEqual(
    broken("Read `.agents/rules/project-profile.md#default-evolution-strategy-and-language`.", "AGENTS.md"),
    [],
  );
  assert.deepEqual(broken("[section](../../rules/project-profile.md#hello-world)"), []);
  assert.deepEqual(broken("[section](../../rules/project-profile.md#repeat-1)"), []);
  assert.deepEqual(broken("[section](../../rules/project-profile.md#a--b)"), []);
  assert.deepEqual(broken("[section](../../rules/project-profile.md#foo-1-1)"), []);
  assert.deepEqual(broken("[section](../../rules/project-profile.md#setext-heading)"), []);
  assert.deepEqual(broken("[section](../../rules/project-profile.md#p0--safety-sources-of-truth)"), []);

  const collapsedHyphen = broken("[section](../../rules/project-profile.md#a-b)");
  assert.equal(collapsedHyphen.length, 1);
  assert.equal(collapsedHyphen[0].reason, "missing-anchor");

  const wrongCaseAndSpaces = broken("[section](../../rules/project-profile.md#Hello%20World)");
  assert.equal(wrongCaseAndSpaces.length, 1);
  assert.equal(wrongCaseAndSpaces[0].reason, "missing-anchor");

  const missing = broken("Read `.agents/rules/project-profile.md#__missing_heading__`.", "AGENTS.md");
  assert.equal(missing.length, 1);
  assert.equal(missing[0].reason, "missing-anchor");
  assert.equal(missing[0].fragment, "__missing_heading__");
});

test("a backtick reference to a concrete repository file goes through the same existence check", () => {
  const missing = findBrokenRepositoryReferences(
    "Fact page: `docs/__audit_missing__.md`.",
    ".agents/rules/project-profile.md",
    () => false,
  );
  assert.equal(missing.length, 1);
  assert.equal(missing[0].repoPath, "docs/__audit_missing__.md");

  const ignored = findBrokenRepositoryReferences(
    [
      "A directory: `game/art/licensed/`.",
      "Generated output: `build/windows/GameBase.exe`.",
      "A command: `node tools/validate.js --skip-soak`.",
      "A glob: `game/**/*.gd`.",
    ].join("\n"),
    ".agents/rules/docs.md",
    () => false,
  );
  assert.deepEqual(ignored, []);
});

test("a reference-style Markdown definition goes through the same check", () => {
  const content = [
    "Required boundary: [read][boundary]",
    "[boundary]: ../../rules/__audit_missing_reference_style__.md",
  ].join("\n");
  const problems = findBrokenRepositoryReferences(
    content,
    ".agents/skills/ui-design/SKILL.md",
    () => false,
  );
  assert.equal(problems.length, 1);
  assert.equal(problems[0].repoPath, ".agents/rules/__audit_missing_reference_style__.md");
});

test("network links, bare anchors and template paths are ignored, and a reference that leaves the repository is rejected", () => {
  const ignored = [
    "[web](https://example.com/docs)",
    "[section](#local-heading)",
    "[template](../../skills/<name>/SKILL.md)",
    "[glob](../../rules/*.md)",
    "`literal example: [fake](../../rules/__inline_code_missing__.md)`",
    "```markdown",
    "[example](../../rules/__inside_fence_missing__.md)",
    "```",
    "> ```markdown",
    "> [example](../../rules/__inside_blockquote_fence_missing__.md)",
    "> ```",
  ].join("\n");
  assert.deepEqual(
    findBrokenRepositoryReferences(ignored, ".agents/skills/ui-design/SKILL.md", () => false),
    [],
  );

  const escaped = findBrokenRepositoryReferences(
    "[outside](../../../../outside.md)",
    ".agents/skills/ui-design/SKILL.md",
    () => true,
  );
  assert.equal(escaped.length, 1);
  assert.equal(escaped[0].reason, "escapes-repository");

  const absoluteLocal = findBrokenRepositoryReferences(
    "[local](C:\\private\\rule.md)",
    ".agents/skills/ui-design/SKILL.md",
    () => true,
  );
  assert.equal(absoluteLocal.length, 1);
  assert.equal(absoluteLocal[0].reason, "escapes-repository");
});

test("the whole check rejects a missing cross-directory link in a real skill file", () => {
  const script = [
    'const fs = require("node:fs");',
    "const originalReadFileSync = fs.readFileSync.bind(fs);",
    "fs.readFileSync = (filePath, ...args) => {",
    "  const content = originalReadFileSync(filePath, ...args);",
    "  const normalized = String(filePath).replaceAll(String.fromCharCode(92), '/');",
    "  if (normalized.endsWith('/.agents/skills/ui-design/SKILL.md') && typeof content === 'string') {",
    "    return content + '\\nRequired boundary: [read](../../rules/__audit_missing__.md)\\n';",
    "  }",
    "  return content;",
    "};",
    'const { validateAgentEntry, validateStructure } = require("./tools/validate_rules.js");',
    'validateAgentEntry("intentionally invalid entry before the real structure check");',
    "process.stdout.write(JSON.stringify(validateStructure()));",
  ].join("\n");
  const result = spawnSync(process.execPath, ["-e", script], { cwd: ROOT, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  const validation = JSON.parse(result.stdout);
  assert.ok(
    validation.errors.some((error) => error.includes(".agents/rules/__audit_missing__.md")),
    JSON.stringify(validation, null, 2),
  );
  assert.equal(
    validation.errors.some((error) => error.includes("the entry must contain")),
    false,
    JSON.stringify(validation, null, 2),
  );
});

test("supporting material must be reachable from its entry, by repository path or by relative link, and an orphan is reported", () => {
  const files = new Map([
    [".agents/skills/demo/SKILL.md", "Read [reference](reference.md) when needed."],
    [".agents/skills/demo/reference.md", "Go deeper with [deep](references/deep.md)."],
    [".agents/skills/demo/references/deep.md", "Go back to `.agents/skills/demo/reference.md` when needed."],
    [".agents/skills/demo/references/orphan.md", "Material without an entry."],
  ]);

  assert.deepEqual(
    findUnreachableMarkdownPaths(".agents/skills/demo/SKILL.md", files),
    [".agents/skills/demo/references/orphan.md"],
  );
});

test("the required path routes cover every path rule owner", () => {
  assert.deepEqual(REQUIRED_AGENT_PATH_ROUTES, [
    ["`game/**/*.gd`", "`.agents/rules/gdscript.md`"],
    ["`gamebase/**/*.gd`", "`.agents/rules/gdscript.md`"],
    ["`test/**/*.gd`", "`.agents/rules/gdscript.md`"],
    ["`game/**/*.tscn`", "`.agents/rules/scenes-resources.md`"],
    ["`game/**/*.tres`", "`.agents/rules/scenes-resources.md`"],
    ["`gamebase/**/*.tscn`", "`.agents/rules/scenes-resources.md`"],
    ["`gamebase/**/*.tres`", "`.agents/rules/scenes-resources.md`"],
    ["`gamebase/core/save/**`", "`.agents/rules/save.md`"],
    ["`game/i18n/**`", "`.agents/rules/localization.md`"],
    ["`test/**`", "`.agents/rules/testing.md`"],
    ["`tools/**`", "`.agents/rules/tools.md`"],
    ["`.github/workflows/**`", "`.agents/rules/ci-performance.md`"],
    ["`docs/**`", "`.agents/rules/docs.md`"],
    ["`addons/**`", "`.agents/rules/addons.md`"],
  ]);

  const routedRules = new Set(REQUIRED_AGENT_PATH_ROUTES.map(([, rule]) => rule.slice(".agents/rules/".length + 1, -1)));
  const rulesWithPath = fs
    .readdirSync(path.join(ROOT, ".agents", "rules"))
    .filter((name) => name.endsWith(".md"))
    .filter((name) => fs.readFileSync(path.join(ROOT, ".agents", "rules", name), "utf8").startsWith("---"));
  assert.deepEqual([...routedRules].sort(), rulesWithPath.sort());
});

test("the path routing table is parsed into rule -> globs, from the Path routing section only", () => {
  const routes = parseAgentPathRoutes([
    "## Path routing",
    "",
    "| Target path | Read this rule first |",
    "| --- | --- |",
    "| `tools/**` | `.agents/rules/tools.md` |",
    "| `game/**/*.gd`, `test/**/*.gd` | `.agents/rules/gdscript.md` |",
    "",
    "## Conditional context",
    "",
    "| The current task needs | Then read |",
    "| --- | --- |",
    "| Authorization | `.agents/rules/project.md` |",
  ].join("\n"));

  assert.deepEqual([...routes.keys()], [".agents/rules/tools.md", ".agents/rules/gdscript.md"]);
  assert.deepEqual([...routes.get(".agents/rules/gdscript.md")], ["game/**/*.gd", "test/**/*.gd"]);
});

test("a rule's front matter path and the root routing table must agree in both directions", () => {
  const routes = new Map([
    [".agents/rules/gdscript.md", new Set(["game/**/*.gd", "test/**/*.gd"])],
    [".agents/rules/ci-performance.md", new Set([".github/workflows/**"])],
    [".agents/rules/tools.md", new Set(["tools/**"])],
  ]);
  const scopes = new Map([
    [".agents/rules/gdscript.md", "game/**/*.gd, test/**/*.gd"],
    [".agents/rules/ci-performance.md", ".github/**"],
    [".agents/rules/tools.md", undefined],
    [".agents/rules/project.md", undefined],
  ]);

  assert.deepEqual(findRulePathScopeMismatches(routes, scopes), [
    {
      rulePath: ".agents/rules/ci-performance.md",
      reason: "mismatch",
      missingInAgents: [".github/**"],
      missingInRule: [".github/workflows/**"],
    },
    { rulePath: ".agents/rules/tools.md", reason: "missing-scope", routed: ["tools/**"] },
  ]);
});

test("the entry rejects a fixed pre-read stack without misjudging a safe read of the target file", () => {
  assert.equal(hasUnconditionalAgentPreload("Before every edit, read architecture.md and docs/RELEASE.md."), true);
  assert.equal(hasUnconditionalAgentPreload("Every task must first read .agents/rules/project.md."), true);
  assert.equal(hasUnconditionalAgentPreload("## Startup order\n1. Read project.md"), true);
  assert.equal(
    hasUnconditionalAgentPreload("Before every edit, read the current contents of the target file."),
    false,
  );
  assert.equal(
    hasUnconditionalAgentPreload("Read docs/RELEASE.md when preparing a release; an ordinary code task reads the target file."),
    false,
  );
});

test("a skill's front matter name can be checked against its directory", () => {
  assert.equal(skillDirectoryName("skills/ui-design/SKILL.md"), "ui-design");
  assert.equal(skillDirectoryName("skills\\project-audit\\SKILL.md"), "project-audit");
});

test("an absolute path of a machine is recognized, and a repository path or a URL is not", () => {
  assert.equal(hasAbsoluteLocalPath("See `A:\\Project\\ReferenceProjects`."), true);
  assert.equal(hasAbsoluteLocalPath("See `/home/user/private-notes`."), true);
  assert.equal(hasAbsoluteLocalPath("Read `.agents/rules/project.md`."), false);
  assert.equal(hasAbsoluteLocalPath("See https://example.com/design."), false);
});

test("the Profile routes to the automation policy", () => {
  assert.equal(hasAutomationPolicyRouting("Automation levels: `docs/AUTOMATION.md`"), true);
  assert.equal(hasAutomationPolicyRouting("Automation levels: `.agents/rules/project.md`"), false);
});

test("text in another script is located by line", () => {
  assert.deepEqual(findNonEnglishLines("first line\nsecond line"), []);
  assert.deepEqual(findNonEnglishLines("first line\n\u4e2d\u6587\nthird\n\u3042"), [2, 4]);
  assert.deepEqual(findNonEnglishLines("an arrow \u2192 and a dash \u2014 are fine"), []);
});

test("the instruction tree of this repository passes the strict check", () => {
  const result = validateStructure();
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.warnings, []);
});
