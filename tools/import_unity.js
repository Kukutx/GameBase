#!/usr/bin/env node
// Imports the assets of an old Unity 2D project into a game of this repository:
//
//   node tools/import_unity.js [--game <id>] [--source <unity project>] [--dry-run]
//
// What it imports is the game's game.json `unity_import` section (see
// docs/UNITY_IMPORT.md): the asset folders to copy (textures, audio, fonts),
// the folders whose every sprite gets an AtlasTexture, the scenes and prefabs
// to convert (tilemaps into TileMapLayers of one shared TileSet, sprites,
// colliders, animators, and the MonoBehaviours the game maps onto scenes of its
// own), the animator controllers (and folders of loose clips) to turn into
// AnimationLibrary resources and
// the ScriptableObject folders to dump as JSON. Everything is written under
// games/<id>/<destination>/, which the import owns and rewrites; the JSON
// dumps of data and scene trees go to artifacts/<id>/unity_import/ for the
// game's own porting work. Unity scripts are never translated: the game
// rewrites its logic in GDScript and maps it in `scripts`.
//
// Godot's .import and .uid files in the destination survive a run.
// --dry-run lists what would be written and writes nothing. WAV files larger
// than `compress_audio_over_bytes`, or in a format Godot cannot import (such as
// ADPCM), are re-encoded to Ogg Vorbis with ffmpeg, which must then be on PATH.
const fs = require("node:fs");
const path = require("node:path");
const { fail, main, parseToolArgs, rootPath, run } = require("./lib/common");
const { gamePath, resolveGame } = require("./lib/games");
const { UnityProject } = require("./lib/unity_project");
const { SceneResolver } = require("./lib/unity_scene");
const { AssetWriter, TileSetBuilder } = require("./lib/unity_assets");
const { AnimationConverter } = require("./lib/unity_animation");
const { SceneConverter } = require("./lib/unity_nodes");
const { parseSingle } = require("./lib/unity_yaml");

const COPIED = new Set([".png", ".jpg", ".jpeg", ".wav", ".ogg", ".mp3", ".ttf", ".otf"]);
const CONFIG_KEYS = new Set([
  "source", "destination", "pixels_per_unit", "y_sort_layer", "copy", "sprites", "scenes", "prefabs",
  "animations", "clip_libraries", "data", "scripts", "skip_objects", "compress_audio_over_bytes", "paths", "id_maps",
]);

const USAGE = "Usage: node tools/import_unity.js [--game <id>] [--source <unity project>] [--dry-run]";

function walk(directory, filter, result = []) {
  if (!fs.existsSync(directory)) return result;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(full, filter, result);
    else if (filter(full)) result.push(full);
  }
  return result.sort();
}

// Whether a WAV file holds PCM or float samples, the only ones Godot imports.
function plainWav(file) {
  const buffer = fs.readFileSync(file);
  for (let offset = 12; offset + 10 <= buffer.length;) {
    const size = buffer.readUInt32LE(offset + 4);
    if (buffer.toString("ascii", offset, offset + 4) === "fmt ") {
      const format = buffer.readUInt16LE(offset + 8);
      return format === 1 || format === 3;
    }
    offset += 8 + size + (size % 2);
  }
  return false;
}

function readConfig(game) {
  const config = game.manifest.unity_import;
  if (!config || typeof config !== "object") fail(`games/${game.id}/game.json has no unity_import section.`);
  for (const key of Object.keys(config)) if (!CONFIG_KEYS.has(key)) fail(`unity_import has an unsupported key '${key}'.`);
  if (!/^game\/[A-Za-z0-9_/-]+$/.test(String(config.destination ?? ""))) fail("unity_import.destination must be a directory under game/.");
  return config;
}

function sortingLayers(source) {
  const file = path.join(source, "ProjectSettings", "TagManager.asset");
  const layers = parseSingle(fs.readFileSync(file, "utf8")).TagManager?.m_SortingLayers ?? [];
  return layers.map((layer, index) => ({ name: String(layer.name), id: String(Number(layer.uniqueID) >>> 0), index }));
}

// A copy of `value` with every asset reference replaced by what it became:
// sprites by their AtlasTexture, other copied files by their path, prefabs and
// scenes by the converted scene, scripts by their class name.
function resolveReferences(value, project, assets, converted) {
  if (Array.isArray(value)) return value.map((entry) => resolveReferences(entry, project, assets, converted));
  if (!value || typeof value !== "object") return value;
  if ("fileID" in value && Object.keys(value).every((key) => ["fileID", "guid", "type"].includes(key))) {
    if (!value.guid) return null;
    const sprite = project.sprite(value);
    if (sprite) return { sprite: assets.atlas(sprite) };
    const asset = project.asset(value.guid);
    if (!asset) return { missing: value.guid };
    if (converted.has(asset.file)) return { scene: converted.get(asset.file) };
    if (COPIED.has(path.extname(asset.file).toLowerCase())) return { file: assets.assetPath(asset.file) };
    if (asset.file.endsWith(".cs")) return { script: path.basename(asset.file, ".cs") };
    return { asset: asset.relative };
  }
  return Object.fromEntries(Object.entries(value).map(([key, entry]) => [key, resolveReferences(entry, project, assets, converted)]));
}

// Every `.import` and `.uid` file under `root`: path -> content.
function readGodotFiles(root) {
  const files = new Map();
  if (!fs.existsSync(root)) return files;
  for (const entry of fs.readdirSync(root, { withFileTypes: true, recursive: true })) {
    if (!entry.isFile() || !/\.(import|uid)$/.test(entry.name)) continue;
    const file = path.join(entry.parentPath, entry.name);
    files.set(file, fs.readFileSync(file));
  }
  return files;
}

// Puts back the files `readGodotFiles` kept whose asset or script was
// written again.
function restoreGodotFiles(files) {
  for (const [file, content] of files) {
    if (fs.existsSync(file.replace(/\.(import|uid)$/, ""))) fs.writeFileSync(file, content);
  }
}

async function importUnity({ game, source, dryRun }) {
  const config = readConfig(game);
  const projectRoot = path.resolve(source || config.source || "");
  if (!fs.existsSync(path.join(projectRoot, "Assets")) || !fs.existsSync(path.join(projectRoot, "ProjectSettings"))) {
    fail(`${projectRoot} is not a Unity project: it needs Assets/ and ProjectSettings/. Pass --source <path>.`);
  }
  const project = new UnityProject(projectRoot);
  const ppu = Number(config.pixels_per_unit ?? 100);
  const destination = String(config.destination);
  const outputRoot = gamePath(game, ...destination.split("/"));
  const artifactRoot = rootPath("artifacts", game.id, "unity_import");
  if (dryRun) {
    console.log(`Would import ${projectRoot} into ${outputRoot} and dump data to ${artifactRoot}:`);
    for (const key of ["copy", "sprites", "scenes", "prefabs", "animations", "data"]) console.log(`  ${key}: ${JSON.stringify(config[key] ?? [])}`);
    return;
  }
  // Godot's own files beside what the import writes (`.import` settings and
  // `.uid` files) keep the ids Godot gave them, so that an import run again
  // changes only what changed.
  const godotFiles = readGodotFiles(outputRoot);
  fs.rmSync(outputRoot, { recursive: true, force: true });
  fs.rmSync(artifactRoot, { recursive: true, force: true });
  const assets = new AssetWriter(project, game.root, destination, ppu, config.paths ?? {});
  const assetsDir = (relative) => path.join(project.assets, ...String(relative).split("/"));

  const compressOver = Number(config.compress_audio_over_bytes ?? 0);
  const pending = [];
  for (const folder of config.copy ?? []) {
    for (const file of walk(assetsDir(folder), (full) => COPIED.has(path.extname(full).toLowerCase()))) {
      const wav = file.toLowerCase().endsWith(".wav");
      if (wav && (!plainWav(file) || (compressOver > 0 && fs.statSync(file).size > compressOver))) {
        assets.assetPath(file, {
          extension: ".ogg",
          convert: (from, to) => pending.push(run("ffmpeg", ["-y", "-loglevel", "error", "-i", from, "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", "6", "-serial_offset", "1", to], { quiet: true })
            .then((result) => { if (result.code !== 0) fail(`ffmpeg could not compress ${from}: ${result.output}`); })),
        });
      } else {
        assets.assetPath(file);
      }
    }
  }
  for (const folder of config.sprites ?? []) {
    const root = assetsDir(folder);
    for (const sprite of project.sprites.values()) if (sprite.file.startsWith(root + path.sep)) assets.atlas(sprite);
  }

  const animations = new AnimationConverter(project, assets);
  const libraries = new Map();
  const library = (controllerFile) => {
    if (!libraries.has(controllerFile)) {
      const resPath = `${assets.resRoot}/${assets.outPath(controllerFile).replace(/\.[^.]+$/, "")}.tres`;
      assets.write(resPath, animations.library(controllerFile));
      const defaultClip = controllerFile.endsWith(".controller") ? animations.defaultClip(controllerFile) : null;
      libraries.set(controllerFile, { path: resPath, defaultClip });
    }
    return libraries.get(controllerFile);
  };
  for (const folder of config.animations ?? []) {
    for (const file of walk(assetsDir(folder), (full) => /\.(controller|overrideController)$/.test(full))) library(file);
  }
  // Clips no controller plays, such as those a script starts, one library per folder.
  for (const folder of config.clip_libraries ?? []) {
    const clips = new Map(walk(assetsDir(folder), (full) => full.endsWith(".anim")).map((file) => [path.basename(file, ".anim"), file]));
    const resPath = `${assets.resRoot}/${assets.outPath(assetsDir(folder))}.tres`;
    assets.write(resPath, animations.clipsLibrary(clips));
    libraries.set(folder, { path: resPath, defaultClip: null });
  }

  const layers = sortingLayers(projectRoot);
  const ySort = layers.find((layer) => layer.name === config.y_sort_layer);
  const tileset = new TileSetBuilder(assets, ppu);
  const tilesetPath = `${assets.resRoot}/tiles/tileset.tres`;
  const locationIds = Object.fromEntries(Object.entries(config.scenes ?? {}));
  const resolver = new SceneResolver(project);
  const converter = new SceneConverter(project, assets, tileset, {
    pixelsPerUnit: ppu,
    sortingLayers: new Map(layers.map((layer) => [layer.id, layer.index])),
    ySortIndex: ySort ? ySort.index : 0,
    scripts: config.scripts ?? {},
    skipObjects: config.skip_objects ?? [],
    locationIds,
    idMaps: config.id_maps ?? {},
    tilesetPath,
    libraries: library,
  });
  const converted = new Map();
  const trees = {};
  for (const folder of config.prefabs ?? []) {
    for (const file of walk(assetsDir(folder), (full) => full.endsWith(".prefab"))) {
      const relative = assets.outPath(file).replace(/\.prefab$/, "");
      const resPath = `${assets.resRoot}/${relative}.tscn`;
      const tree = resolver.tree(file);
      assets.write(resPath, converter.convert(tree, path.basename(relative), { prefab: true }));
      converted.set(file, resPath);
      trees[`prefab:${relative}`] = tree;
    }
  }
  for (const [sceneName, id] of Object.entries(config.scenes ?? {})) {
    const file = path.join(project.assets, "Scenes", `${sceneName}.unity`);
    const sceneFile = fs.existsSync(file) ? file : walk(project.assets, (full) => path.basename(full) === `${sceneName}.unity`)[0];
    if (!sceneFile) fail(`unity_import.scenes names ${sceneName}, which the project does not hold.`);
    const tree = resolver.tree(sceneFile);
    const resPath = `${assets.resRoot}/scenes/${id}.tscn`;
    assets.write(resPath, converter.convert(tree, id));
    converted.set(sceneFile, resPath);
    trees[`scene:${sceneName}`] = tree;
  }
  assets.write(tilesetPath, tileset.toString());

  fs.mkdirSync(artifactRoot, { recursive: true });
  for (const folder of config.data ?? []) {
    for (const file of walk(assetsDir(folder), (full) => full.endsWith(".asset"))) {
      const relative = path.relative(project.assets, file).split(path.sep).join("/").replace(/\.asset$/, ".json");
      const documents = [...project.load(file).values()].map((document) => ({
        type: document.type,
        script: project.scriptName(document),
        data: resolveReferences(document.data, project, assets, converted),
      }));
      const target = path.join(artifactRoot, "data", ...relative.split("/"));
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, `${JSON.stringify(documents, null, 1)}\n`);
    }
  }
  const strip = (nodes) => nodes.map((node) => ({
    name: node.name,
    active: node.active,
    position: node.transform?.m_LocalPosition ?? null,
    components: node.components.map((component) => ({ type: component.type, script: component.script, data: resolveReferences(component.data, project, assets, converted) })),
    children: strip(node.children),
  }));
  fs.writeFileSync(path.join(artifactRoot, "trees.json"), `${JSON.stringify(Object.fromEntries(Object.entries(trees).map(([key, tree]) => [key, strip(tree)])), null, 1)}\n`);
  await Promise.all(pending);
  restoreGodotFiles(godotFiles);

  for (const warning of [...assets.warnings].sort()) console.warn(`warning: ${warning}`);
  console.log(`Imported ${assets.copied.size} file(s), ${assets.atlases.size} sprite(s), ${libraries.size} animation librar(ies), ${converted.size} scene(s) and prefab(s) into ${outputRoot}.`);
  console.log(`Data and scene trees for porting: ${artifactRoot}`);
}

if (require.main === module) {
  main(async () => {
    const { values } = parseToolArgs({
      options: {
        game: { type: "string" },
        source: { type: "string" },
        "dry-run": { type: "boolean", default: false },
        help: { type: "boolean", default: false },
      },
      strict: true,
    });
    if (values.help) {
      console.log(USAGE);
      return;
    }
    await importUnity({ game: resolveGame(values.game), source: values.source, dryRun: values["dry-run"] });
  });
}

module.exports = { importUnity, resolveReferences };
