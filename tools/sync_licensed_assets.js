const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { extractZip } = require("./lib/archive");
const { fail, main, rootPath } = require("./lib/common");

// The owner's local archive locations; see docs/LICENSED_ASSETS.md. Override
// them with --gandalf-root and --craftpix-archive on another machine.
const DEFAULT_GANDALF_ROOT = "A:\\Project\\Godot\\Asset\\GandalfHardcore";
const DEFAULT_CRAFTPIX_ARCHIVE = "A:\\Project\\Godot\\Asset\\参考\\craftpix-net-436971-free-top-down-roguelike-game-kit-pixel-art.zip";

const GANDALF_PACKS = [
  { zip: "GandalfHardcore Pixel Art Village Houses tiles.zip", folder: "GandalfHardcore Pixel Art Village Houses tiles", destination: "gandalf_village" },
  { zip: "GandalfHardcore Farming Tiles and Crops 32x32.zip", folder: "GandalfHardcore Farming Tiles and Crops 32x32", destination: "gandalf_farming" },
  { zip: "GandalfHardcore House Asset Pack 32x32.zip", folder: "GandalfHardcore House Asset Pack 32x32", destination: "gandalf_house" },
  { zip: "GandalfHardcore Farm Animals.zip", folder: "GandalfHardcore Farm Animals", destination: "gandalf_animals" },
  { zip: "GandalfHardcore Slime Enemy.zip", folder: "GandalfHardcore Slime Enemy", destination: "gandalf_slime" },
];
const CRAFTPIX_STRIPS = ["D", "U", "S"].flatMap((direction) =>
  ["Idle", "Walk", "Attack", "Hurt", "Death"].map((action) => `${direction}_${action}.png`),
);

function syncLicensedAssets({ gandalfRoot, craftpixArchive }) {
  const destinationRoot = rootPath("game", "art", "licensed");
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "gamebase-licensed-assets-"));
  fs.mkdirSync(destinationRoot, { recursive: true });
  try {
    for (const pack of GANDALF_PACKS) {
      const zipPath = path.join(gandalfRoot, pack.zip);
      if (!fs.existsSync(zipPath)) {
        fail(`Missing licensed source archive: ${zipPath}`);
      }
      const extractRoot = path.join(tempRoot, pack.destination);
      extractZip(zipPath, extractRoot);
      const sourceFolder = path.join(extractRoot, pack.folder);
      const destination = path.join(destinationRoot, pack.destination);
      fs.mkdirSync(destination, { recursive: true });
      for (const entry of fs.readdirSync(sourceFolder, { withFileTypes: true })) {
        if (entry.isFile() && entry.name.toLowerCase().endsWith(".png")) {
          fs.copyFileSync(path.join(sourceFolder, entry.name), path.join(destination, entry.name));
        }
      }
    }

    if (!fs.existsSync(craftpixArchive)) {
      fail(`Missing Craftpix source archive: ${craftpixArchive}`);
    }
    const craftpixExtract = path.join(tempRoot, "craftpix_roguelike");
    extractZip(craftpixArchive, craftpixExtract);
    for (const characterId of [1, 2, 3]) {
      const source = path.join(craftpixExtract, "1 Characters", String(characterId));
      const destination = path.join(destinationRoot, "craftpix_roguelike", `character${characterId}`);
      fs.mkdirSync(destination, { recursive: true });
      for (const name of CRAFTPIX_STRIPS) {
        const file = path.join(source, name);
        if (!fs.existsSync(file)) {
          fail(`Missing Craftpix character strip: ${file}`);
        }
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
    const { values } = parseArgs({
      options: {
        "gandalf-root": { type: "string", default: DEFAULT_GANDALF_ROOT },
        "craftpix-archive": { type: "string", default: DEFAULT_CRAFTPIX_ARCHIVE },
      },
    });
    syncLicensedAssets({ gandalfRoot: values["gandalf-root"], craftpixArchive: values["craftpix-archive"] });
  });
}
