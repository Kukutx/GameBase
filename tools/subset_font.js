const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { fail, main, removeRecursive, rootPath, run, tempFile } = require("./lib/common");

// Builds the font every game shows its text in unless its theme names another:
// Noto Sans SC (licenses/NOTO_SANS_SC_LICENSE.txt) cut down to Latin, the
// punctuation of Chinese text, the GB 2312 area (its 6763 common hanzi and its
// symbols) and every character in the text files of the foundation and the
// games. A Web build has no system fonts to fall back on, so a character
// missing here shows as a box; the core's test_theme_font checks every
// translation a game registers against the font.
//
// Run it after adding text the font may lack, with fontTools' pyftsubset on the
// PATH (python3 -m pip install fonttools brotli) and the full font from Google
// Fonts (fonts.google.com/noto/specimen/Noto+Sans+SC):
//
//   node tools/subset_font.js --source <NotoSansSC-Regular.ttf>

const OUTPUT = rootPath("gamebase", "core", "ui", "fonts", "noto_sans_sc.woff2");
// Files whose text a game shows: translations, dialogue, and the scripts and
// resources that hold text of their own (the language names).
const TEXT_EXTENSIONS = new Set([".po", ".dialogue", ".gd", ".tres", ".tscn"]);
const RANGES = [
  [0x0020, 0x007e], // ASCII
  [0x00a0, 0x017f], // Latin-1 and Latin Extended-A
  [0x2010, 0x2027], // dashes, quotes, ellipsis
  [0x2030, 0x203a], // per mille, primes, angle quotes
  [0x2190, 0x2193], // arrows
  [0x3000, 0x303f], // CJK symbols and punctuation
  [0xff01, 0xff5e], // full-width forms
];

// Every character of the GB 2312 rows, as GBK reads them; the rows GBK leaves
// to the user (private use) are not characters.
function gb2312Characters(found) {
  const decoder = new TextDecoder("gbk", { fatal: true });
  for (let first = 0xa1; first <= 0xf7; first++) {
    for (let second = 0xa1; second <= 0xfe; second++) {
      let code;
      try {
        code = decoder.decode(Uint8Array.of(first, second)).codePointAt(0);
      } catch {
        continue;
      }
      if (code !== undefined && !(code >= 0xe000 && code <= 0xf8ff)) found.add(code);
    }
  }
}

// Every character outside ASCII in the text files of the foundation and the
// games. The links inside a game point back at the shared copy, so they are
// not walked.
function repositoryCharacters(found, directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isSymbolicLink() || entry.name === ".godot" || entry.name === "addons") continue;
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      repositoryCharacters(found, absolute);
    } else if (TEXT_EXTENSIONS.has(path.extname(entry.name))) {
      for (const character of fs.readFileSync(absolute, "utf8")) {
        const code = character.codePointAt(0);
        if (code > 0x7e) found.add(code);
      }
    }
  }
}

function fontCharacters() {
  const found = new Set();
  gb2312Characters(found);
  repositoryCharacters(found, rootPath("gamebase"));
  repositoryCharacters(found, rootPath("games"));
  for (const [low, high] of RANGES) {
    for (let code = low; code <= high; code++) found.add(code);
  }
  found.delete(0xfeff);
  return [...found].sort((a, b) => a - b);
}

async function subsetFont(source) {
  if (!fs.existsSync(source)) fail(`Source font not found: ${source}`);
  const characters = fontCharacters();
  const list = tempFile("gamebase-font-characters");
  fs.writeFileSync(list, characters.map((code) => `U+${code.toString(16).toUpperCase().padStart(4, "0")}`).join("\n"), "utf8");
  try {
    // Characters the source lacks are left out; test_theme_font names any a
    // translation needs.
    const result = await run("pyftsubset", [
      path.resolve(source),
      `--unicodes-file=${list}`,
      "--flavor=woff2",
      "--layout-features=*",
      "--name-IDs=*",
      "--notdef-outline",
      "--drop-tables+=vhea,vmtx,STAT",
      `--output-file=${OUTPUT}`,
    ]);
    if (result.code !== 0) fail(`pyftsubset failed with exit code ${result.code}.`);
  } finally {
    removeRecursive(list);
  }
  console.log(`Wrote ${path.relative(rootPath(), OUTPUT)}: ${characters.length} characters asked for, ${fs.statSync(OUTPUT).size} bytes`);
}

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({ options: { source: { type: "string" } } });
    if (!values.source) fail("Usage: node tools/subset_font.js --source <NotoSansSC-Regular.ttf>");
    await subsetFont(values.source);
  });
}
