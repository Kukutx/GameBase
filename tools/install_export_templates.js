const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { extractZip } = require("./lib/archive");
const { ENGINE_VERSION_RE, download, fail, main, readTrimmed, removeRecursive, rootPath } = require("./lib/common");

const REQUIRED_TEMPLATES = ["windows_release_x86_64.exe", "linux_release.x86_64", "web_nothreads_release.zip"];

// Where the Godot editor looks for export templates on each platform.
function templatesRoot() {
  if (process.platform === "win32") {
    return path.join(process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming"), "Godot", "export_templates");
  }
  if (process.platform === "darwin") {
    return path.join(os.homedir(), "Library", "Application Support", "Godot", "export_templates");
  }
  return path.join(process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share"), "godot", "export_templates");
}

function missingTemplates(destination) {
  return REQUIRED_TEMPLATES.filter((name) => !fs.existsSync(path.join(destination, name)));
}

async function installExportTemplates({ version, cacheDirectory, force = false }) {
  const resolvedVersion = version || readTrimmed(".godot-version");
  if (!ENGINE_VERSION_RE.test(resolvedVersion)) {
    fail(`Expected a stable Godot 4.x version such as 4.7.2; got '${resolvedVersion}'.`);
  }
  const devRoot = rootPath(".dev");
  fs.mkdirSync(devRoot, { recursive: true });
  const cache = cacheDirectory ? path.resolve(cacheDirectory) : path.join(devRoot, "export-templates");
  fs.mkdirSync(cache, { recursive: true });

  const destination = path.join(templatesRoot(), `${resolvedVersion}.stable`);
  if (!force && fs.existsSync(destination) && missingTemplates(destination).length === 0) {
    console.log(`Godot ${resolvedVersion} export templates are already installed.`);
    console.log(destination);
    return;
  }

  const packagePath = path.join(cache, `Godot_v${resolvedVersion}-stable_export_templates.tpz`);
  const url = `https://github.com/godotengine/godot/releases/download/${resolvedVersion}-stable/Godot_v${resolvedVersion}-stable_export_templates.tpz`;
  console.log(`Downloading Godot ${resolvedVersion} export templates...`);
  await download(url, packagePath);

  const extractRoot = path.join(cache, `extract-${resolvedVersion}`);
  removeRecursive(extractRoot);
  extractZip(packagePath, extractRoot);
  let source = path.join(extractRoot, "templates");
  if (!fs.existsSync(source)) {
    const candidate = fs
      .readdirSync(extractRoot, { withFileTypes: true })
      .find((entry) => entry.isDirectory() && fs.existsSync(path.join(extractRoot, entry.name, "version.txt")));
    if (!candidate) {
      fail(`Could not locate the templates directory inside '${packagePath}'.`);
    }
    source = path.join(extractRoot, candidate.name);
  }

  removeRecursive(destination);
  fs.mkdirSync(destination, { recursive: true });
  fs.cpSync(source, destination, { recursive: true });
  const missing = missingTemplates(destination);
  if (missing.length > 0) {
    fail(`Template installation is incomplete. Missing: ${missing.join(", ")}`);
  }
  removeRecursive(extractRoot);
  console.log(`Installed Godot ${resolvedVersion} export templates:`);
  console.log(destination);
}

if (require.main === module) {
  main(async () => {
    const { values } = parseArgs({
      options: {
        version: { type: "string" },
        "cache-directory": { type: "string" },
        force: { type: "boolean", default: false },
      },
    });
    await installExportTemplates({
      version: values.version,
      cacheDirectory: values["cache-directory"],
      force: values.force,
    });
  });
}
