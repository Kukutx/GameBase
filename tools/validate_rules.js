// Checks the agent instruction tree: the root AGENTS.md and everything under
// .agents/. It verifies structure, routing and references only; it says nothing
// about how a model behaves with these rules.
const fs = require("node:fs");
const path = require("node:path");
const { ROOT, main, rootPath } = require("./lib/common");

const AGENTS_DIR = rootPath(".agents");
const RULES_DIR = path.join(AGENTS_DIR, "rules");
const AGENT_ENTRY_PATH = rootPath("AGENTS.md");
const PROJECT_PROFILE_PATH = path.join(RULES_DIR, "project-profile.md");
const AUTOMATION_POLICY_REPO_PATH = "docs/AUTOMATION.md";

const CLI_FLAGS = Object.freeze({
  strict: "--strict",
  report: "--report",
});

const REQUIRED_RULE_FILES = [
  "project.md",
  "gdscript.md",
  "scenes-resources.md",
  "save.md",
  "localization.md",
  "testing.md",
  "tools.md",
  "docs.md",
  "addons.md",
];

const REQUIRED_AGENTS_FILES = [
  "rules/project-profile.md",
  "rules/project-domain.md",
  "rules/ci-performance.md",
  "workflows/agent-workflow-guide.md",
  "workflows/agent-pressure-tests.md",
  "workflows/instruction-readiness.md",
  "workflows/product-assurance.md",
  "prompts/agent-compliance-policy-assistant.md",
  "prompts/agent-prompt-shortcuts.md",
  "templates/atomic-change-checklist.md",
  "templates/decision-record-template.md",
  "templates/project-audit-report.md",
  "standards/skill-authoring.md",
  "skills/content-authoring/SKILL.md",
  "skills/content-authoring/reference.md",
  "skills/game-qa/SKILL.md",
  "skills/project-audit/SKILL.md",
  "skills/reference-projects/SKILL.md",
  "skills/replication/SKILL.md",
  "skills/solution-grill/SKILL.md",
  "skills/toolchain/SKILL.md",
  "skills/ui-design/SKILL.md",
];

const REQUIRED_RULE_SECTIONS = {
  "project.md": ["P0", "P1", "P2", "Architecture ownership and the abstraction gate", "Reuse across systems"],
  "gdscript.md": ["P0", "P1", "P2"],
  "scenes-resources.md": ["P0", "P1", "P2"],
  "save.md": ["P0", "P1"],
  "localization.md": ["P0", "P1"],
  "testing.md": ["P0", "P1"],
  "tools.md": ["P0", "P1", "P2"],
  "docs.md": ["P0", "P1", "P2"],
  "addons.md": ["P0", "P1"],
};

const REQUIRED_CORE_PRESSURE_TESTS = Array.from(
  { length: 36 },
  (_, index) => `A${String(index + 1).padStart(2, "0")}`,
);
const REQUIRED_BOUNDARY_PRESSURE_TESTS = [
  "G05", "G06", "G08", "G09", "G10", "G11", "G12", "G13", "G14", "G15", "G16", "G17", "G18", "G19", "G20",
];
const REQUIRED_SKILL_ROUTING_TESTS = Array.from(
  { length: 7 },
  (_, index) => `H${String(index + 1).padStart(2, "0")}`,
);
const REQUIRED_VERIFICATION_SEMANTICS_TESTS = Array.from(
  { length: 6 },
  (_, index) => `I${String(index + 1).padStart(2, "0")}`,
);
const REQUIRED_PRESSURE_TESTS = [
  ...REQUIRED_CORE_PRESSURE_TESTS,
  ...REQUIRED_BOUNDARY_PRESSURE_TESTS,
  ...REQUIRED_SKILL_ROUTING_TESTS,
  ...REQUIRED_VERIFICATION_SEMANTICS_TESTS,
];

const REQUIRED_AGENT_PATH_ROUTES = [
  ["`gamebase/**/*.gd`", "`.agents/rules/gdscript.md`"],
  ["`games/*/game/**/*.gd`", "`.agents/rules/gdscript.md`"],
  ["`games/*/test/**/*.gd`", "`.agents/rules/gdscript.md`"],
  ["`gamebase/**/*.tscn`", "`.agents/rules/scenes-resources.md`"],
  ["`gamebase/**/*.tres`", "`.agents/rules/scenes-resources.md`"],
  ["`games/*/game/**/*.tscn`", "`.agents/rules/scenes-resources.md`"],
  ["`games/*/game/**/*.tres`", "`.agents/rules/scenes-resources.md`"],
  ["`gamebase/core/save/**`", "`.agents/rules/save.md`"],
  ["`games/*/game/i18n/**`", "`.agents/rules/localization.md`"],
  ["`games/*/test/**`", "`.agents/rules/testing.md`"],
  ["`tools/**`", "`.agents/rules/tools.md`"],
  ["`.github/workflows/**`", "`.agents/rules/ci-performance.md`"],
  ["`docs/**`", "`.agents/rules/docs.md`"],
  ["`addons/**`", "`.agents/rules/addons.md`"],
];

const REQUIRED_AGENT_ENTRY_TEXT = [
  "Path routing",
  "Conditional context",
  ".agents/rules/project.md",
  ".agents/workflows/agent-workflow-guide.md",
  ".agents/workflows/instruction-readiness.md",
  ".agents/prompts/agent-compliance-policy-assistant.md",
];

// The directory note is written for maintainers. It is not part of the chain an
// agent loads, so it takes no part in the reachability check.
const AGENTS_REACHABILITY_EXEMPT_BASENAMES = new Set(["README.md"]);

const PRIORITY_LEVELS = ["P0", "P1", "P2"];
const PROMPT_RISK_PHRASES = [
  "You are a specialist responsible only for",
  "Your responsibilities include only",
  "is absolutely forbidden",
  "This request is outside my responsibilities",
  "I will not directly",
];
const REPOSITORY_BACKTICK_PREFIXES = [
  ".agents/",
  ".github/",
  "addons/",
  "docs/",
  "gamebase/",
  "games/",
  "licenses/",
  "tools/",
];
const REPOSITORY_ROOT_FILES = new Set([
  "AGENTS.md",
  "README.md",
  "THIRD_PARTY_NOTICES.md",
  ".godot-version",
]);
// The repository is open source and its instruction tree is written in English.
const NON_ENGLISH_SCRIPT_RE = /[぀-ヿ㐀-鿿가-힯＀-￯]/u;

let errors = [];
let warnings = [];

function resetState() {
  errors = [];
  warnings = [];
}

function toRepoPath(filePath) {
  return path.relative(ROOT, filePath).replaceAll("\\", "/");
}

function stripFencedCodeBlocks(content) {
  const lines = String(content).split(/\r?\n/);
  let fenceChar = null;
  let fenceLength = 0;

  return lines.map((line) => {
    const match = /^\s*(?:>\s*)*(`{3,}|~{3,})/.exec(line);
    if (match) {
      const marker = match[1];
      if (fenceChar === null) {
        fenceChar = marker[0];
        fenceLength = marker.length;
      } else if (marker[0] === fenceChar && marker.length >= fenceLength) {
        fenceChar = null;
        fenceLength = 0;
      }
      return "";
    }
    return fenceChar === null ? line : "";
  }).join("\n");
}

function hasTemplateReferenceSyntax(target) {
  return /[*{}]|<[^>]+>/.test(target);
}

function extractAgentsReferences(content) {
  const prose = stripFencedCodeBlocks(content);
  return [...prose.matchAll(/`(\.agents\/[^`]+)`/g)]
    .map((match) => match[1])
    .filter(
      (reference) =>
        !reference.includes("*") &&
        !reference.includes("<") &&
        !reference.includes(">"),
    );
}

function extractConcreteRepositoryBacktickTargets(content) {
  const prose = stripFencedCodeBlocks(content);
  const targets = [];
  for (const match of prose.matchAll(/`([^`\r\n]+)`/g)) {
    const target = match[1].trim();
    const [targetPath] = target.split(/[?#]/);
    if (!targetPath || /\s/.test(targetPath) || hasTemplateReferenceSyntax(targetPath)) continue;
    const normalized = targetPath.replaceAll("\\", "/");
    if (normalized.endsWith("/")) continue;
    const basename = path.posix.basename(normalized);
    const fileLike = basename.includes(".") || REPOSITORY_ROOT_FILES.has(normalized);
    if (!fileLike) continue;
    if (!REPOSITORY_ROOT_FILES.has(normalized) && !REPOSITORY_BACKTICK_PREFIXES.some((prefix) => normalized.startsWith(prefix))) {
      continue;
    }
    targets.push(target);
  }
  return targets;
}

function stripInlineCodeSpans(content) {
  return String(content).replace(/(`+)([\s\S]*?)\1/g, (match) => match.replace(/[^\n]/g, " "));
}

function parseInlineMarkdownDestination(prose, startIndex) {
  let index = startIndex;
  while (/\s/.test(prose[index] || "")) index += 1;
  if (index >= prose.length) return null;

  if (prose[index] === "<") {
    const start = index;
    index += 1;
    let escaped = false;
    while (index < prose.length) {
      const char = prose[index];
      if (!escaped && char === ">") return prose.slice(start, index + 1);
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      index += 1;
    }
    return null;
  }

  const start = index;
  let depth = 0;
  let escaped = false;
  while (index < prose.length) {
    const char = prose[index];
    if (escaped) {
      escaped = false;
      index += 1;
      continue;
    }
    if (char === "\\") {
      escaped = true;
      index += 1;
      continue;
    }
    if (char === "(") {
      depth += 1;
      index += 1;
      continue;
    }
    if (char === ")") {
      if (depth === 0) return index > start ? prose.slice(start, index) : null;
      depth -= 1;
      index += 1;
      continue;
    }
    if (/\s/.test(char) && depth === 0) {
      return index > start ? prose.slice(start, index) : null;
    }
    index += 1;
  }
  return null;
}

function extractInlineMarkdownLinkTargets(prose) {
  const targets = [];
  const bracketStack = [];
  let escaped = false;

  for (let index = 0; index < prose.length; index += 1) {
    const char = prose[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === "\\") {
      escaped = true;
      continue;
    }
    if (char === "[") {
      bracketStack.push(index);
      continue;
    }
    if (char !== "]" || bracketStack.length === 0) continue;

    bracketStack.pop();
    if (prose[index + 1] !== "(") continue;
    const target = parseInlineMarkdownDestination(prose, index + 2);
    if (target) targets.push(target);
  }

  return targets;
}

function extractMarkdownLinkTargets(content) {
  const prose = stripInlineCodeSpans(stripFencedCodeBlocks(content));
  const targets = extractInlineMarkdownLinkTargets(prose);

  for (const match of prose.matchAll(/^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)/gm)) {
    targets.push(match[1]);
  }

  return targets;
}

function normalizeMarkdownDestination(rawTarget) {
  let target = String(rawTarget || "").trim();
  if (!target) return "";

  if (target.startsWith("<")) {
    const closing = target.indexOf(">");
    if (closing === -1) return "";
    target = target.slice(1, closing).trim();
  } else {
    target = target.split(/\s+/)[0];
  }

  return target.trim();
}

function resolveRepositoryReference(rawTarget, currentRepoPath, kind = "markdown") {
  const target = normalizeMarkdownDestination(rawTarget);
  if (!target || target.startsWith("#")) return null;
  if (/^[A-Za-z]:[\\/]/.test(target) || /^\\\\/.test(target) || /^file:/i.test(target)) {
    return { rawTarget: target, repoPath: null, escapesRepository: true };
  }
  if (/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(target)) return null;
  if (target.startsWith("/")) return null;

  const [targetPath] = target.split(/[?#]/);
  if (!targetPath || hasTemplateReferenceSyntax(targetPath)) return null;

  let decodedTargetPath;
  try {
    decodedTargetPath = decodeURIComponent(targetPath);
  } catch {
    decodedTargetPath = targetPath;
  }
  const markdownUnescapedTarget = decodedTargetPath.replace(/\\([()[\]{}])/g, "$1");
  const normalizedTarget = markdownUnescapedTarget.replaceAll("\\", "/");
  const currentPath = currentRepoPath.replaceAll("\\", "/");
  const repoPath = kind === "agents" || kind === "repo-root" || normalizedTarget.startsWith(".agents/")
    ? path.posix.normalize(normalizedTarget)
    : path.posix.normalize(path.posix.join(path.posix.dirname(currentPath), normalizedTarget));

  if (repoPath === ".." || repoPath.startsWith("../") || path.posix.isAbsolute(repoPath)) {
    return { rawTarget: target, repoPath: null, escapesRepository: true };
  }

  return { rawTarget: target, repoPath, escapesRepository: false };
}

function extractRepositoryReferences(content, currentRepoPath) {
  const references = new Map();

  for (const target of extractAgentsReferences(content)) {
    const resolved = resolveRepositoryReference(target, currentRepoPath, "agents");
    if (!resolved) continue;
    references.set(`backtick:${resolved.rawTarget}`, resolved);
  }

  for (const target of extractConcreteRepositoryBacktickTargets(content)) {
    if (target.startsWith(".agents/")) continue;
    const resolved = resolveRepositoryReference(target, currentRepoPath, "repo-root");
    if (!resolved) continue;
    references.set(`backtick:${resolved.rawTarget}`, resolved);
  }

  for (const target of extractMarkdownLinkTargets(content)) {
    const resolved = resolveRepositoryReference(target, currentRepoPath, "markdown");
    if (!resolved) continue;
    references.set(`markdown:${resolved.rawTarget}`, resolved);
  }

  return [...references.values()];
}

function extractReferenceFragment(rawTarget) {
  const target = normalizeMarkdownDestination(rawTarget);
  const hashIndex = target.indexOf("#");
  if (hashIndex === -1) return "";
  let fragment = target.slice(hashIndex + 1).split("?")[0].trim();
  if (!fragment) return "";
  try {
    fragment = decodeURIComponent(fragment);
  } catch {
    // Keep the literal fragment so a malformed escape cannot silently bypass validation.
  }
  return fragment;
}

function normalizeHeadingText(rawHeading) {
  return String(rawHeading)
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/\[([^\]]+)\]\[[^\]]+\]/g, "$1")
    .replace(/[`*_~]/g, "")
    .replace(/<[^>]+>/g, "")
    .trim();
}

// Heading anchors as GitHub renders them: lower case, punctuation removed,
// each space turned into a hyphen, and a numeric suffix for a repeated heading.
function createHeadingSlugger() {
  const occurrences = new Map();
  return (heading) => {
    const base = heading
      .toLowerCase()
      .replace(/[^\p{L}\p{M}\p{N}\p{Pc}\- ]/gu, "")
      .replace(/ /g, "-");
    let slug = base;
    let count = occurrences.get(base) ?? 0;
    while (occurrences.has(slug)) {
      count += 1;
      slug = `${base}-${count}`;
    }
    occurrences.set(base, count);
    occurrences.set(slug, 0);
    return slug;
  };
}

function collectMarkdownHeadingAnchors(content) {
  const anchors = new Set();
  const slug = createHeadingSlugger();
  const addHeading = (rawHeading) => {
    const heading = normalizeHeadingText(rawHeading);
    if (!heading) return;
    const anchor = slug(heading);
    if (anchor) anchors.add(anchor);
  };

  const lines = stripFencedCodeBlocks(content).split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const atx = /^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$/.exec(lines[index]);
    if (atx) {
      addHeading(atx[1]);
      continue;
    }
    if (
      lines[index].trim() &&
      index + 1 < lines.length &&
      /^\s{0,3}(?:=+|-+)\s*$/.test(lines[index + 1])
    ) {
      addHeading(lines[index]);
      index += 1;
    }
  }
  return anchors;
}

function findBrokenRepositoryReferences(content, currentRepoPath, exists = null, readText = null) {
  const pathExists = exists ?? ((repoPath) => fs.existsSync(rootPath(repoPath)));
  const pathReader = readText ?? (exists === null
    ? ((repoPath) => fs.readFileSync(rootPath(repoPath), "utf8"))
    : null);
  const problems = [];

  for (const reference of extractRepositoryReferences(content, currentRepoPath)) {
    if (reference.escapesRepository) {
      problems.push({ ...reference, reason: "escapes-repository" });
      continue;
    }
    if (!pathExists(reference.repoPath)) {
      problems.push({ ...reference, reason: "missing" });
      continue;
    }

    const fragment = extractReferenceFragment(reference.rawTarget);
    if (!fragment || !reference.repoPath.toLowerCase().endsWith(".md") || !pathReader) continue;
    let targetContent;
    try {
      targetContent = pathReader(reference.repoPath);
    } catch (error) {
      problems.push({ ...reference, fragment, reason: "unreadable", detail: error.message });
      continue;
    }
    if (!collectMarkdownHeadingAnchors(targetContent).has(fragment)) {
      problems.push({ ...reference, fragment, reason: "missing-anchor" });
    }
  }

  return problems;
}

function extractPressureTestScenarios(content) {
  return [...content.matchAll(/^##\s+([A-Z]\d{2}[a-z]?):/gm)].map((match) => match[1]);
}

function findUnsupportedCliFlags(args) {
  const supportedFlags = new Set([...Object.values(CLI_FLAGS), "--help", "-h"]);
  return args.filter((arg) => arg.startsWith("-") && !supportedFlags.has(arg));
}

function hasUnconditionalAgentPreload(content) {
  if (/^##\s*(?:Startup order|Boot sequence|Reading order)\s*$/im.test(content)) return true;

  const preloadPatterns = [
    /\b(?:before|for|on)\s+(?:every|any|all|each)\s+(?:tasks?|edits?|changes?)\b[^\n]{0,120}\b(?:read|load|open)\b/i,
    /\b(?:every|any|all|each)\s+(?:tasks?|edits?|changes?)\b[^\n]{0,80}\b(?:must|should|always)\b[^\n]{0,60}\b(?:read|load|open)\b/i,
    /\balways\s+(?:read|load|open)\b[^\n]{0,80}\b(?:first|before)\b/i,
  ];
  const safeTargetReadPatterns = [
    /\b(?:target|current)\s+file\b/i,
    /\bcurrent\s+contents?\s+of\b/i,
    /\bfiles?\s+(?:you\s+)?(?:will|plan\s+to)\s+edit\b/i,
  ];
  const broadContextPatterns = [
    /(?:project(?:-profile|-domain)?\.md|architecture\.md|RELEASE\.md|AGENTS\.md|\.agents\/|workflow|skill|docs?\b|manual|handbook|the rules|whole repository)/i,
  ];

  for (const line of content.split(/\r?\n/)) {
    if (!preloadPatterns.some((pattern) => pattern.test(line))) continue;
    const safeTargetRead = safeTargetReadPatterns.some((pattern) => pattern.test(line));
    const broadContextRead = broadContextPatterns.some((pattern) => pattern.test(line));
    if (safeTargetRead && !broadContextRead) continue;
    return true;
  }
  return false;
}

function validateAgentEntry(content = null) {
  if (content === null && !fs.existsSync(AGENT_ENTRY_PATH)) {
    errors.push("Missing the agent entry file: AGENTS.md");
    return;
  }

  const source = content ?? fs.readFileSync(AGENT_ENTRY_PATH, "utf8");

  for (const requiredText of REQUIRED_AGENT_ENTRY_TEXT) {
    if (!source.includes(requiredText)) {
      errors.push(`AGENTS.md: the entry must contain "${requiredText}"`);
    }
  }

  for (const [pathPattern, rulePath] of REQUIRED_AGENT_PATH_ROUTES) {
    const routed = source
      .split(/\r?\n/)
      .some((line) => line.includes(pathPattern) && line.includes(rulePath));
    if (!routed) {
      errors.push(`AGENTS.md: missing the path route ${pathPattern} -> ${rulePath}`);
    }
  }

  if (/^##\s*(?:Fixed red lines|Red lines|Hard rules)\s*$/im.test(source)) {
    errors.push("AGENTS.md: do not copy a list of fixed red lines; route the detailed boundaries to .agents/rules/project.md on demand");
  }

  if (hasUnconditionalAgentPreload(source)) {
    errors.push("AGENTS.md: project material must not be written as a fixed pre-read stack for every task; route context on demand");
  }
}

function extractMarkdownSection(content, heading) {
  const lines = String(content).split(/\r?\n/);
  const start = lines.findIndex((line) => new RegExp(`^##\\s+${heading}\\s*$`).test(line));
  if (start === -1) return "";
  const end = lines.findIndex((line, index) => index > start && /^##\s/.test(line));
  return lines.slice(start + 1, end === -1 ? undefined : end).join("\n");
}

// Parses the "Path routing" table of AGENTS.md into: rule path -> the set of globs routed to it.
function parseAgentPathRoutes(content) {
  const routes = new Map();
  for (const line of extractMarkdownSection(content, "Path routing").split("\n")) {
    if (!line.trim().startsWith("|")) continue;
    const cells = line.split("|").slice(1, -1);
    if (cells.length < 2) continue;
    const patterns = [...cells[0].matchAll(/`([^`]+)`/g)].map((match) => match[1]);
    for (const [, target] of cells[1].matchAll(/`([^`]+)`/g)) {
      if (!routes.has(target)) routes.set(target, new Set());
      for (const pattern of patterns) routes.get(target).add(pattern);
    }
  }
  return routes;
}

function parseRulePathScope(value) {
  return new Set(String(value).split(",").map((item) => item.trim()).filter(Boolean));
}

// The frontmatter `path` of a rule and the root routing table must agree in both
// directions, so that no second routing table can drift away from the first.
function findRulePathScopeMismatches(agentRoutes, ruleScopes) {
  const problems = [];
  for (const [rulePath, declaredValue] of ruleScopes) {
    const routed = agentRoutes.get(rulePath) ?? new Set();
    if (declaredValue === undefined) {
      if (routed.size > 0) problems.push({ rulePath, reason: "missing-scope", routed: [...routed] });
      continue;
    }
    const declared = parseRulePathScope(declaredValue);
    const missingInAgents = [...declared].filter((pattern) => !routed.has(pattern));
    const missingInRule = [...routed].filter((pattern) => !declared.has(pattern));
    if (missingInAgents.length > 0 || missingInRule.length > 0) {
      problems.push({ rulePath, reason: "mismatch", missingInAgents, missingInRule });
    }
  }
  return problems;
}

function validateRulePathScopes(agentContent = null) {
  if (agentContent === null && !fs.existsSync(AGENT_ENTRY_PATH)) return;
  const agentRoutes = parseAgentPathRoutes(agentContent ?? fs.readFileSync(AGENT_ENTRY_PATH, "utf8"));
  const ruleScopes = new Map();
  for (const entry of fs.readdirSync(RULES_DIR, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith(".md") || AGENTS_REACHABILITY_EXEMPT_BASENAMES.has(entry.name)) continue;
    const content = fs.readFileSync(path.join(RULES_DIR, entry.name), "utf8");
    const fields = content.startsWith("---") ? parseFrontMatterData(content).fields : null;
    ruleScopes.set(`.agents/rules/${entry.name}`, fields?.get("path"));
  }

  for (const problem of findRulePathScopeMismatches(agentRoutes, ruleScopes)) {
    if (problem.reason === "missing-scope") {
      errors.push(`${problem.rulePath}: AGENTS.md routes ${problem.routed.join(", ")} to it, but the file has no frontmatter path`);
      continue;
    }
    if (problem.missingInAgents.length > 0) {
      errors.push(`${problem.rulePath}: the frontmatter path declares ${problem.missingInAgents.join(", ")}, which AGENTS.md does not route`);
    }
    if (problem.missingInRule.length > 0) {
      errors.push(`${problem.rulePath}: AGENTS.md routes ${problem.missingInRule.join(", ")}, which the frontmatter path does not declare`);
    }
  }
}

// Every Markdown file under .agents must be reachable from AGENTS.md through
// on-demand routing; an agent never loads a file that nothing points to.
function validateAgentsReachability() {
  if (!fs.existsSync(AGENT_ENTRY_PATH)) return;
  const markdownByPath = new Map([["AGENTS.md", fs.readFileSync(AGENT_ENTRY_PATH, "utf8")]]);
  for (const markdownPath of collectMarkdownFiles(AGENTS_DIR)) {
    if (AGENTS_REACHABILITY_EXEMPT_BASENAMES.has(path.basename(markdownPath))) continue;
    markdownByPath.set(toRepoPath(markdownPath), fs.readFileSync(markdownPath, "utf8"));
  }
  for (const unreachablePath of findUnreachableMarkdownPaths("AGENTS.md", markdownByPath)) {
    errors.push(`${unreachablePath}: not reachable from AGENTS.md through on-demand routing; add a route or delete the orphan file`);
  }
}

function hasAutomationPolicyRouting(content) {
  return content.includes(AUTOMATION_POLICY_REPO_PATH);
}

function validateAutomationPolicyRouting() {
  const policyExists = fs.existsSync(rootPath(AUTOMATION_POLICY_REPO_PATH));
  const profileContent = fs.existsSync(PROJECT_PROFILE_PATH)
    ? fs.readFileSync(PROJECT_PROFILE_PATH, "utf8")
    : "";
  const hasRouting = hasAutomationPolicyRouting(profileContent);

  if (policyExists && !hasRouting) {
    errors.push(`project-profile.md: the automation policy exists, but the Profile does not route to ${AUTOMATION_POLICY_REPO_PATH}`);
  }
  if (!policyExists && hasRouting) {
    errors.push(`project-profile.md: a route points to ${AUTOMATION_POLICY_REPO_PATH}, which does not exist`);
  }
}

function validateRuleFile(filePath, fileName) {
  const content = fs.readFileSync(filePath, "utf8");

  for (const section of REQUIRED_RULE_SECTIONS[fileName] || []) {
    const present = PRIORITY_LEVELS.includes(section)
      ? new RegExp(`^##\\s+${section}(?:\\s|$)`, "m").test(content)
      : content.includes(section);
    if (!present) {
      errors.push(`${fileName}: missing the required section "${section}"`);
    }
  }

  for (const level of PRIORITY_LEVELS) {
    const matches = content.match(new RegExp(`^##\\s+${level}(?:\\s|$)`, "gm")) || [];
    if (matches.length > 1) {
      warnings.push(`${fileName}: found ${matches.length} top-level "${level}" sections; check for a formatting mistake`);
    }
  }

  if (content.startsWith("---") && content.indexOf("---", 3) === -1) {
    errors.push(`${fileName}: malformed YAML front matter (no closing marker)`);
  }
}

// Reads one front matter value. The instruction tree only uses single-line
// string scalars, so anything else is reported instead of being interpreted.
function parseFrontMatterScalar(raw) {
  const value = raw.trim();
  if (value === "") return { problem: "must not be empty" };
  if (value.startsWith('"')) {
    try {
      const parsed = JSON.parse(value);
      return typeof parsed === "string" ? { value: parsed } : { problem: "must be a string" };
    } catch {
      return { problem: "has an unterminated or invalid double-quoted string" };
    }
  }
  if (value.startsWith("'")) {
    const inner = value.slice(1, -1);
    if (value.length < 2 || !value.endsWith("'") || inner.replaceAll("''", "").includes("'")) {
      return { problem: "has an unterminated or invalid single-quoted string" };
    }
    return { value: inner.replaceAll("''", "'") };
  }
  if (/^[[{>|*&!%@`]/.test(value)) return { problem: "must be a single-line string; quote the value" };
  if (/:\s/.test(value) || value.endsWith(":") || /\s#/.test(value)) {
    return { problem: 'contains ": " or " #", which YAML does not accept in a plain value; quote the value' };
  }
  if (/^(?:true|false|null|yes|no|on|off|~)$/i.test(value) || /^[-+]?(?:\d[\d_]*)?\.?\d+(?:e[-+]?\d+)?$/i.test(value)) {
    return { problem: "must be a string" };
  }
  return { value };
}

function parseFrontMatterData(content) {
  const problems = [];
  const match = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(content);
  if (!match) {
    problems.push(content.startsWith("---")
      ? "malformed YAML front matter (no closing marker)"
      : "missing YAML front matter");
    return { fields: null, problems };
  }

  const fields = new Map();
  for (const line of match[1].split(/\r?\n/)) {
    if (line.trim() === "" || line.trimStart().startsWith("#")) continue;
    const entry = /^([A-Za-z0-9_-]+):(?:\s+(.*))?$/.exec(line);
    if (!entry) {
      problems.push(`front matter line is not a "key: value" pair: ${line.trim()}`);
      continue;
    }
    const [, key, raw = ""] = entry;
    if (fields.has(key)) {
      problems.push(`front matter field "${key}" is duplicated`);
      continue;
    }
    const scalar = parseFrontMatterScalar(raw);
    if (scalar.problem) {
      problems.push(`front matter field "${key}" ${scalar.problem}`);
      continue;
    }
    fields.set(key, scalar.value);
  }
  return problems.length > 0 ? { fields: null, problems } : { fields, problems };
}

function parseFrontMatter(content, fileName) {
  const result = parseFrontMatterData(content);
  for (const problem of result.problems) {
    errors.push(`${fileName}: ${problem}`);
  }
  return result.problems.length === 0 ? result.fields : null;
}

function skillDirectoryName(relativePath) {
  return relativePath.replaceAll("\\", "/").split("/").at(-2) ?? "";
}

function hasAbsoluteLocalPath(content) {
  return /(?:^|[\s`"'(])(?:[A-Za-z]:[\\/]|\\\\[^\\/\r\n]+[\\/]|\/(?:Users|home)\/)/m.test(content);
}

function validateSkillFile(filePath, relativePath) {
  const content = fs.readFileSync(filePath, "utf8");
  const fields = parseFrontMatter(content, relativePath);

  if (fields) {
    const allowedFields = new Set(["name", "description"]);
    for (const key of fields.keys()) {
      if (!allowedFields.has(key)) {
        errors.push(`${relativePath}: front matter allows only name and description, found "${key}"`);
      }
    }
    for (const key of allowedFields) {
      if (!fields.get(key)) {
        errors.push(`${relativePath}: front matter is missing "${key}"`);
      }
    }

    const directoryName = skillDirectoryName(relativePath);
    if (directoryName && fields.get("name") !== directoryName) {
      errors.push(`${relativePath}: the front matter name must equal the skill directory name (expected "${directoryName}")`);
    }
  }

  if (hasAbsoluteLocalPath(content)) {
    errors.push(`${relativePath}: a skill must not hard-code an absolute path of a machine`);
  }
}

function directoryContainsFiles(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isFile()) return true;
    if (entry.isDirectory() && directoryContainsFiles(entryPath)) return true;
  }
  return false;
}

function extractRoutedMarkdownReferences(content, currentPath) {
  return extractRepositoryReferences(content, currentPath)
    .filter((reference) => !reference.escapesRepository && reference.repoPath?.toLowerCase().endsWith(".md"))
    .map((reference) => reference.repoPath);
}

function findUnreachableMarkdownPaths(entryPath, markdownByPath) {
  if (!markdownByPath.has(entryPath)) return [...markdownByPath.keys()].sort();

  const reachable = new Set([entryPath]);
  const queue = [entryPath];
  while (queue.length > 0) {
    const currentPath = queue.shift();
    const content = markdownByPath.get(currentPath) ?? "";
    for (const target of extractRoutedMarkdownReferences(content, currentPath)) {
      if (!markdownByPath.has(target) || reachable.has(target)) continue;
      reachable.add(target);
      queue.push(target);
    }
  }

  return [...markdownByPath.keys()].filter((item) => !reachable.has(item)).sort();
}

function validateSkills() {
  const skillsDir = path.join(AGENTS_DIR, "skills");
  if (!fs.existsSync(skillsDir)) return;

  const skillNames = fs
    .readdirSync(skillsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();

  for (const skillName of skillNames) {
    const skillDir = path.join(skillsDir, skillName);
    const relativePath = `skills/${skillName}/SKILL.md`;
    const skillPath = path.join(skillDir, "SKILL.md");
    if (!fs.existsSync(skillPath)) {
      // An empty directory is not a skill; it is a structure error only while it still holds files.
      if (!directoryContainsFiles(skillDir)) continue;
      errors.push(`Missing the skill entry file: ${relativePath}`);
      continue;
    }
    validateSkillFile(skillPath, relativePath);

    const markdownPaths = collectMarkdownFiles(skillDir);
    const markdownByPath = new Map(
      markdownPaths.map((markdownPath) => [toRepoPath(markdownPath), fs.readFileSync(markdownPath, "utf8")]),
    );
    for (const unreachablePath of findUnreachableMarkdownPaths(toRepoPath(skillPath), markdownByPath)) {
      errors.push(`${relativePath}: supporting material is not reachable from SKILL.md: "${unreachablePath}"`);
    }

    for (const markdownPath of markdownPaths) {
      if (markdownPath === skillPath) continue;
      if (!hasAbsoluteLocalPath(fs.readFileSync(markdownPath, "utf8"))) continue;
      errors.push(`${path.relative(AGENTS_DIR, markdownPath).replaceAll("\\", "/")}: skill reference material must not hard-code an absolute path of a machine`);
    }
  }
}

function validatePressureTests() {
  const relativePath = "workflows/agent-pressure-tests.md";
  const filePath = path.join(AGENTS_DIR, relativePath);
  if (!fs.existsSync(filePath)) return;

  const scenarios = extractPressureTestScenarios(fs.readFileSync(filePath, "utf8"));
  const scenarioSet = new Set(scenarios);

  for (const scenario of REQUIRED_PRESSURE_TESTS) {
    if (!scenarioSet.has(scenario)) {
      errors.push(`${relativePath}: missing the required pressure-test scenario ${scenario}`);
    }
  }

  for (const scenario of new Set(scenarios.filter((item, index) => scenarios.indexOf(item) !== index))) {
    errors.push(`${relativePath}: the pressure-test scenario ${scenario} is duplicated`);
  }

  if (scenarios.length === 0) {
    errors.push(`${relativePath}: found no scenario heading of the form "## A01: title"`);
  }
}

function collectMarkdownFiles(directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...collectMarkdownFiles(entryPath));
    else if (entry.isFile() && entry.name.endsWith(".md")) files.push(entryPath);
  }
  return files;
}

function fileSourceBytes(filePath) {
  return fs.existsSync(filePath) ? fs.statSync(filePath).size : 0;
}

function sumSourceBytes(filePaths) {
  return filePaths.reduce((total, filePath) => total + fileSourceBytes(filePath), 0);
}

function collectInstructionFootprint() {
  const agentEntryBytes = fileSourceBytes(AGENT_ENTRY_PATH);
  const pathRuleFiles = REQUIRED_RULE_FILES.filter((fileName) => fileName !== "project.md");
  const typicalPathRoutes = Object.fromEntries(
    pathRuleFiles.map((fileName) => [
      fileName,
      agentEntryBytes + fileSourceBytes(path.join(RULES_DIR, fileName)),
    ]),
  );

  const skillsDir = path.join(AGENTS_DIR, "skills");
  const skills = {};
  if (fs.existsSync(skillsDir)) {
    for (const entry of fs.readdirSync(skillsDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const skillDir = path.join(skillsDir, entry.name);
      const skillPath = path.join(skillDir, "SKILL.md");
      if (!fs.existsSync(skillPath)) continue;
      const supportPaths = collectMarkdownFiles(skillDir).filter((filePath) => filePath !== skillPath);
      skills[entry.name] = {
        root: fileSourceBytes(skillPath),
        support: sumSourceBytes(supportPaths),
      };
    }
  }

  const promptsDir = path.join(AGENTS_DIR, "prompts");
  const recipesDir = path.join(promptsDir, "recipes");
  const recipePaths = fs.existsSync(recipesDir) ? collectMarkdownFiles(recipesDir) : [];

  return {
    unit: "source_bytes",
    note: "Source bytes are a reproducible footprint diagnostic, not tokenizer counts or actual per-task loaded context.",
    agentEntry: agentEntryBytes,
    typicalPathRoutes,
    conditionalCore: {
      project: fileSourceBytes(path.join(RULES_DIR, "project.md")),
      profile: fileSourceBytes(PROJECT_PROFILE_PATH),
      domain: fileSourceBytes(path.join(RULES_DIR, "project-domain.md")),
      workflowGuide: fileSourceBytes(path.join(AGENTS_DIR, "workflows", "agent-workflow-guide.md")),
      instructionReadiness: fileSourceBytes(path.join(AGENTS_DIR, "workflows", "instruction-readiness.md")),
    },
    skills,
    prompts: {
      compliance: fileSourceBytes(path.join(promptsDir, "agent-compliance-policy-assistant.md")),
      index: fileSourceBytes(path.join(promptsDir, "agent-prompt-shortcuts.md")),
      recipes: sumSourceBytes(recipePaths),
    },
    storedAgentsMarkdownTotal: sumSourceBytes(collectMarkdownFiles(AGENTS_DIR)),
  };
}

function printInstructionFootprint(report = collectInstructionFootprint()) {
  console.log("");
  console.log("Agent instruction footprint (source bytes; not token counts):");
  console.log(`  AGENTS.md: ${report.agentEntry}`);
  console.log("  Typical AGENTS.md + one path rule:");
  for (const [fileName, bytes] of Object.entries(report.typicalPathRoutes)) {
    console.log(`    ${fileName}: ${bytes}`);
  }
  console.log("  Conditional core:");
  for (const [name, bytes] of Object.entries(report.conditionalCore)) {
    console.log(`    ${name}: ${bytes}`);
  }
  console.log("  Skill roots / support:");
  for (const [name, footprint] of Object.entries(report.skills).sort(([a], [b]) => a.localeCompare(b))) {
    console.log(`    ${name}: root=${footprint.root}, support=${footprint.support}`);
  }
  console.log(`  Compliance prompt / fixed-recipe index / recipes: ${report.prompts.compliance} / ${report.prompts.index} / ${report.prompts.recipes}`);
  console.log(`  Stored .agents Markdown total: ${report.storedAgentsMarkdownTotal}`);
  console.log(`  Note: ${report.note}`);
}

function instructionSourceFiles() {
  return [AGENT_ENTRY_PATH, ...collectMarkdownFiles(AGENTS_DIR)].filter((filePath) => fs.existsSync(filePath));
}

function validateAgentsReferences() {
  for (const filePath of instructionSourceFiles()) {
    const content = fs.readFileSync(filePath, "utf8");
    const repoRelativePath = toRepoPath(filePath);

    for (const problem of findBrokenRepositoryReferences(content, repoRelativePath)) {
      if (problem.reason === "escapes-repository") {
        errors.push(`${repoRelativePath}: a local reference leaves the repository: "${problem.rawTarget}"`);
      } else if (problem.reason === "missing-anchor") {
        errors.push(`${repoRelativePath}: the referenced section does not exist: "${problem.rawTarget}" -> "${problem.repoPath}#${problem.fragment}"`);
      } else if (problem.reason === "unreadable") {
        errors.push(`${repoRelativePath}: the local reference cannot be read: "${problem.rawTarget}" -> "${problem.repoPath}" (${problem.detail})`);
      } else {
        errors.push(`${repoRelativePath}: the local reference does not exist: "${problem.rawTarget}" -> "${problem.repoPath}"`);
      }
    }
  }
}

function findNonEnglishLines(content) {
  return String(content)
    .split(/\r?\n/)
    .map((line, index) => ({ line: index + 1, text: line }))
    .filter((item) => NON_ENGLISH_SCRIPT_RE.test(item.text))
    .map((item) => item.line);
}

function validateInstructionLanguage() {
  for (const filePath of instructionSourceFiles()) {
    const lines = findNonEnglishLines(fs.readFileSync(filePath, "utf8"));
    if (lines.length > 0) {
      errors.push(`${toRepoPath(filePath)}: the instruction tree is written in English; found another script on line ${lines.slice(0, 5).join(", ")}`);
    }
  }
}

function validatePrompts() {
  const promptsDir = path.join(AGENTS_DIR, "prompts");
  if (!fs.existsSync(promptsDir)) return;

  for (const promptPath of collectMarkdownFiles(promptsDir).sort()) {
    const relativePath = path.relative(AGENTS_DIR, promptPath).replaceAll("\\", "/");
    const content = fs.readFileSync(promptPath, "utf8");

    for (const phrase of PROMPT_RISK_PHRASES) {
      if (content.includes(phrase)) {
        warnings.push(`${relativePath}: found wording that leads to wrong refusals or a hard-coded identity: "${phrase}"`);
      }
    }
  }

  const recipeIndexPath = path.join(promptsDir, "agent-prompt-shortcuts.md");
  const recipesDir = path.join(promptsDir, "recipes");
  if (fs.existsSync(recipeIndexPath) && fs.existsSync(recipesDir)) {
    const routedFiles = [recipeIndexPath, ...collectMarkdownFiles(recipesDir)];
    const markdownByPath = new Map(
      routedFiles.map((filePath) => [toRepoPath(filePath), fs.readFileSync(filePath, "utf8")]),
    );
    const entryPath = toRepoPath(recipeIndexPath);
    for (const unreachablePath of findUnreachableMarkdownPaths(entryPath, markdownByPath)) {
      if (unreachablePath === entryPath) continue;
      errors.push(`prompts/agent-prompt-shortcuts.md: a fixed recipe is not reachable from the index: "${unreachablePath}"`);
    }
  }
}

function validateStructure() {
  resetState();
  if (!fs.existsSync(RULES_DIR)) {
    errors.push("Missing the rules directory: .agents/rules");
    return { errors: [...errors], warnings: [...warnings] };
  }

  validateAgentEntry();
  validateAutomationPolicyRouting();

  for (const file of REQUIRED_AGENTS_FILES) {
    if (!fs.existsSync(path.join(AGENTS_DIR, file))) {
      errors.push(`Missing an agent instruction file: .agents/${file}`);
    }
  }

  validateSkills();
  validatePressureTests();
  validatePrompts();
  validateAgentsReferences();
  validateInstructionLanguage();
  validateRulePathScopes();
  validateAgentsReachability();

  for (const file of REQUIRED_RULE_FILES) {
    const filePath = path.join(RULES_DIR, file);
    if (!fs.existsSync(filePath)) {
      errors.push(`Missing a required rule file: .agents/rules/${file}`);
      continue;
    }
    validateRuleFile(filePath, file);
  }
  return { errors: [...errors], warnings: [...warnings] };
}

const USAGE = [
  "Usage: node tools/validate_rules.js [--strict] [--report]",
  "",
  "--strict    treat warnings as errors",
  "--report    print the read-only source-byte footprint of the instruction tree (not a token count)",
  "--help, -h  show this help",
].join("\n");

// Runs the check and prints its result. Returns the process exit code.
function runCli(args) {
  const unsupportedFlags = findUnsupportedCliFlags(args);
  if (unsupportedFlags.length > 0) {
    console.error(`validate_rules does not support: ${unsupportedFlags.join(", ")}`);
    return 1;
  }
  if (args.includes("--help") || args.includes("-h")) {
    console.log(USAGE);
    return 0;
  }

  const result = validateStructure();
  if (args.includes(CLI_FLAGS.report)) {
    printInstructionFootprint();
  }
  if (args.includes(CLI_FLAGS.strict) && result.warnings.length > 0) {
    result.errors.push("Strict mode: resolve the warnings above first");
  }

  for (const warning of result.warnings) {
    console.warn(`WARNING: ${warning}`);
  }
  for (const error of result.errors) {
    console.error(`FAILED: ${error}`);
  }
  if (result.errors.length > 0) {
    console.error(`Agent rules check failed with ${result.errors.length} problem(s).`);
    return 1;
  }
  console.log("Agent rules and routing check passed.");
  return 0;
}

module.exports = {
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
  runCli,
  skillDirectoryName,
  validateAgentEntry,
  validateRuleFile,
  validateStructure,
};

if (require.main === module) {
  main(() => runCli(process.argv.slice(2)));
}
