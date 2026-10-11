const fs = require("node:fs");
const { parseArgs } = require("node:util");
const { validate } = require("./validate");
const { GAME_VERSION_RE, fail, main, projectName, rootPath } = require("./lib/common");

async function updateGameVersion({ version, godotBin }) {
  if (!version || !GAME_VERSION_RE.test(version)) {
    fail("Use a semantic game version such as 0.1.0 or 1.0.0-rc.1: node tools/update_game_version.js --version <semver>");
  }
  fs.writeFileSync(rootPath(".game-version"), `${version}\n`, "utf8");

  const projectPath = rootPath("project.godot");
  const project = fs.readFileSync(projectPath, "utf8");
  const versionLine = `config/version="${version}"`;
  let updated;
  if (/^config\/version="[^"]*"$/m.test(project)) {
    updated = project.replace(/^config\/version="[^"]*"$/m, versionLine);
  } else if (/^config\/name="[^"]*"$/m.test(project)) {
    updated = project.replace(/^(config\/name="[^"]*")$/m, `$1\n${versionLine}`);
  } else {
    fail("project.godot has neither a config/version line nor the config/name line to place it after.");
  }
  fs.writeFileSync(projectPath, updated, "utf8");

  console.log(`${projectName()} application version updated to ${version}.`);
  console.log("The Godot engine baseline remains independent in .godot-version.");
  if (godotBin) {
    await validate({ godotBin });
  }
}

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: { version: { type: "string" }, "godot-bin": { type: "string" } },
    });
    await updateGameVersion({ version: values.version, godotBin: values["godot-bin"] });
  });
}
