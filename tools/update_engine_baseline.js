const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { validate } = require("./validate");
const { ENGINE_VERSION_RE, download, fail, main, rootPath } = require("./lib/common");

async function updateEngineBaseline({ version, godotBin }) {
  if (!version || !ENGINE_VERSION_RE.test(version)) {
    fail("Use a stable Godot 4.x semantic version such as 4.7.2: node tools/update_engine_baseline.js --version <x.y.z>");
  }
  const devRoot = rootPath(".dev");
  fs.mkdirSync(devRoot, { recursive: true });
  if (!fs.existsSync(path.join(devRoot, ".gdignore"))) {
    fs.writeFileSync(path.join(devRoot, ".gdignore"), "");
  }
  const tag = `${version}-stable`;
  const tempLicense = path.join(devRoot, `godot-license-${version}.tmp`);
  const tempCopyright = path.join(devRoot, `godot-copyright-${version}.tmp`);
  try {
    console.log(`Downloading official Godot ${tag} legal files...`);
    await download(`https://raw.githubusercontent.com/godotengine/godot/${tag}/LICENSE.txt`, tempLicense);
    await download(`https://raw.githubusercontent.com/godotengine/godot/${tag}/COPYRIGHT.txt`, tempCopyright);
    const license = fs.readFileSync(tempLicense, "utf8");
    const copyright = fs.readFileSync(tempCopyright, "utf8");
    if (license.length < 500 || !license.includes("Godot Engine contributors")) {
      fail(`Downloaded LICENSE.txt does not look like the official Godot license for ${tag}.`);
    }
    if (copyright.length < 10000 || !copyright.includes("Exhaustive licensing information")) {
      fail(`Downloaded COPYRIGHT.txt does not look like the official Godot copyright bundle for ${tag}.`);
    }

    // The version moves only after both official files are downloaded and
    // validated, so a network failure cannot leave a half-upgraded baseline.
    fs.mkdirSync(rootPath("licenses"), { recursive: true });
    fs.writeFileSync(rootPath(".godot-version"), `${version}\n`, "utf8");
    fs.writeFileSync(rootPath("licenses", "GODOT_VERSION.txt"), `${version}\n`, "utf8");
    fs.writeFileSync(rootPath("licenses", "GODOT_LICENSE.txt"), license, "utf8");
    fs.writeFileSync(rootPath("licenses", "GODOT_COPYRIGHT.txt"), copyright, "utf8");
    console.log(`CI validation baseline updated to Godot ${version}.`);
    console.log("Official Godot LICENSE/COPYRIGHT synchronized to the same stable tag.");
    console.log("This does not hard-lock local development to that patch version.");
  } finally {
    fs.rmSync(tempLicense, { force: true });
    fs.rmSync(tempCopyright, { force: true });
  }
  if (godotBin) {
    await validate({ godotBin });
  }
}

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: { version: { type: "string" }, "godot-bin": { type: "string" } },
    });
    await updateEngineBaseline({ version: values.version, godotBin: values["godot-bin"] });
  });
}
