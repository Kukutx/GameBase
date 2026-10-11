// Restores a game's purchased art from the owner's local source archives into
// the Git-ignored games/<id>/game/art/licensed/ tree:
//
//   node tools/sync_licensed_assets.js [--game <id>] [--source <name>=<path>]...
//
// The game's game.json lists the sources under licensed_art.sources (a
// directory or a ZIP archive on the owner's machine; --source overrides one on
// another machine) and the packs to extract under licensed_art.packs: which
// source, the ZIP inside a source directory when there is one, the folder in
// the archive, the files ("*.png" or a list of names) and the destination
// under game/art/licensed/. See docs/LICENSED_ASSETS.md.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { extractZip } = require("./lib/archive");
const { fail, main } = require("./lib/common");
const { gamePath, resolveGame } = require("./lib/games");

function selectFiles(folder, files) {
  if (files === "*.png") {
    return fs.readdirSync(folder, { withFileTypes: true }).filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".png")).map((entry) => entry.name);
  }
  if (!Array.isArray(files) || files.length === 0) fail(`A licensed art pack must list its files or use "*.png".`);
  return files;
}

function syncLicensedAssets({ game, overrides }) {
  const config = game.manifest.licensed_art;
  if (!config) fail(`games/${game.id}/game.json has no licensed_art.`);
  const sources = { ...config.sources, ...overrides };
  const destinationRoot = gamePath(game, "game", "art", "licensed");
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "gamebase-licensed-assets-"));
  const extracted = new Map(); // archive path -> extraction directory
  fs.mkdirSync(destinationRoot, { recursive: true });
  try {
    for (const pack of config.packs || []) {
      if (!sources[pack.source]) fail(`Licensed art pack ${pack.destination} names unknown source '${pack.source}'.`);
      const archive = pack.archive ? path.join(sources[pack.source], pack.archive) : sources[pack.source];
      if (!fs.existsSync(archive)) fail(`Missing licensed source archive: ${archive}`);
      if (!extracted.has(archive)) {
        const target = path.join(tempRoot, String(extracted.size));
        extractZip(archive, target);
        extracted.set(archive, target);
      }
      const folder = path.join(extracted.get(archive), ...pack.folder.split("/"));
      const destination = path.join(destinationRoot, ...pack.destination.split("/"));
      fs.mkdirSync(destination, { recursive: true });
      for (const name of selectFiles(folder, pack.files)) {
        const file = path.join(folder, name);
        if (!fs.existsSync(file)) fail(`Missing licensed file: ${file}`);
        fs.copyFileSync(file, path.join(destination, name));
      }
    }
    console.log(`Licensed art synchronized to ${destinationRoot}`);
  } finally {
    fs.rmSync(tempRoot, { recursive: true, force: true });
  }
}

if (require.main === module) {
  main(() => {
    const { values } = parseArgs({ options: { game: { type: "string" }, source: { type: "string", multiple: true } } });
    const overrides = {};
    for (const entry of values.source || []) {
      const separator = entry.indexOf("=");
      if (separator <= 0) fail(`--source expects <name>=<path>; got '${entry}'.`);
      overrides[entry.slice(0, separator)] = entry.slice(separator + 1);
    }
    syncLicensedAssets({ game: resolveGame(values.game), overrides });
  });
}
