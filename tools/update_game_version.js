const fs = require("node:fs");
const { parseArgs } = require("node:util");
const { validate } = require("./validate");
const { GAME_VERSION_RE, fail, main } = require("./lib/common");
const { gameName, gamePath, resolveGame } = require("./lib/games");

// A game's version lives only in `config/version` of its project.godot; its
// release tag is game/<id>/v<version>. The engine baseline is separate.
async function updateGameVersion({ game, version, godotBin }) {
  if (!version || !GAME_VERSION_RE.test(version)) {
    fail("Use a semantic game version such as 0.1.0 or 1.0.0-rc.1: node tools/update_game_version.js [--game <id>] --version <semver>");
  }
  const projectPath = gamePath(game, "project.godot");
  const project = fs.readFileSync(projectPath, "utf8");
  const versionLine = `config/version="${version}"`;
  let updated;
  if (/^config\/version="[^"]*"$/m.test(project)) {
    updated = project.replace(/^config\/version="[^"]*"$/m, versionLine);
  } else if (/^config\/name="[^"]*"$/m.test(project)) {
    updated = project.replace(/^(config\/name="[^"]*")$/m, `$1\n${versionLine}`);
  } else {
    fail(`games/${game.id}/project.godot has neither a config/version line nor the config/name line to place it after.`);
  }
  fs.writeFileSync(projectPath, updated, "utf8");

  console.log(`${gameName(game)} (games/${game.id}) version updated to ${version}.`);
  if (godotBin) {
    await validate({ godotBin, games: [game.id] });
  }
}

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: { game: { type: "string" }, version: { type: "string" }, "godot-bin": { type: "string" } },
    });
    await updateGameVersion({ game: resolveGame(values.game), version: values.version, godotBin: values["godot-bin"] });
  });
}
