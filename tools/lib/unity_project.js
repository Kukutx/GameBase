"use strict";
// Indexes a Unity project for tools/import_unity.js: every asset by its GUID
// (from the .meta files), the sprites each texture is sliced into, and the
// documents of scenes, prefabs and assets, read once and kept.
const fs = require("node:fs");
const path = require("node:path");
const { parseDocuments, parseSingle } = require("./unity_yaml");

// Unity's fixed file id of the one sprite of a texture in single-sprite mode.
const SINGLE_SPRITE_FILE_ID = "21300000";
// Pivot of each SpriteAlignment value, from the bottom left, 9 being custom.
const ALIGNMENT_PIVOTS = [
  [0.5, 0.5], [0, 1], [0.5, 1], [1, 1], [0, 0.5], [1, 0.5], [0, 0], [0.5, 0], [1, 0],
];

function refKey(guid, fileId) {
  return `${guid}:${String(fileId)}`;
}

// Width and height of a PNG from its IHDR chunk, or of a JPEG from its first
// frame header.
function imageSize(file) {
  const buffer = fs.readFileSync(file);
  if (buffer.readUInt32BE(0) === 0x89504e47) return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
  let offset = 2;
  while (offset < buffer.length) {
    const marker = buffer.readUInt16BE(offset);
    const length = buffer.readUInt16BE(offset + 2);
    if (marker >= 0xffc0 && marker <= 0xffcf && marker !== 0xffc4 && marker !== 0xffc8 && marker !== 0xffcc) {
      return { height: buffer.readUInt16BE(offset + 5), width: buffer.readUInt16BE(offset + 7) };
    }
    offset += 2 + length;
  }
  throw new Error(`cannot read the size of ${file}`);
}

class UnityProject {
  constructor(root) {
    this.root = root;
    this.assets = path.join(root, "Assets");
    this.byGuid = new Map();
    this.sprites = new Map();
    this.documents = new Map();
    this.scriptNames = new Map();
    this.index(this.assets);
  }

  index(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const full = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        this.index(full);
      } else if (entry.name.endsWith(".meta")) {
        const target = full.slice(0, -5);
        if (!fs.existsSync(target) || fs.statSync(target).isDirectory()) continue;
        const meta = parseSingle(fs.readFileSync(full, "utf8"));
        const guid = String(meta.guid ?? "");
        if (!guid) continue;
        const relative = path.relative(this.assets, target).split(path.sep).join("/");
        this.byGuid.set(guid, { guid, file: target, relative, meta });
        if (target.endsWith(".cs")) this.scriptNames.set(guid, path.basename(target, ".cs"));
        if (meta.TextureImporter) this.indexSprites(guid, target, meta.TextureImporter);
      }
    }
  }

  indexSprites(guid, file, importer) {
    let size;
    try {
      size = imageSize(file);
    } catch {
      return;
    }
    const pixelsPerUnit = Number(importer.spritePixelsToUnits ?? 100);
    const pivotOf = (alignment, pivot) => {
      const preset = ALIGNMENT_PIVOTS[Number(alignment)];
      return preset ? { x: preset[0], y: preset[1] } : { x: Number(pivot?.x ?? 0.5), y: Number(pivot?.y ?? 0.5) };
    };
    // A nine-slice border (left, top, right, bottom in pixels), or null.
    const borderOf = (border) => {
      const values = [border?.x, border?.w, border?.z, border?.y].map((entry) => Math.round(Number(entry ?? 0)));
      return values.some((entry) => entry !== 0) ? values : null;
    };
    const add = (fileId, name, rect, pivot, border) => {
      this.sprites.set(refKey(guid, fileId), {
        guid,
        fileId: String(fileId),
        name,
        file,
        textureWidth: size.width,
        textureHeight: size.height,
        pixelsPerUnit,
        // Godot regions count from the top left; Unity rects from the bottom left.
        region: { x: rect.x, y: size.height - rect.y - rect.height, width: rect.width, height: rect.height },
        // Pivot in pixels from the region's top left.
        pivot: { x: pivot.x * rect.width, y: (1 - pivot.y) * rect.height },
        border: borderOf(border),
      });
    };
    const sheet = importer.spriteSheet?.sprites ?? [];
    if (Number(importer.spriteMode) === 2 && Array.isArray(sheet) && sheet.length > 0) {
      for (const sprite of sheet) {
        const rect = {
          x: Number(sprite.rect.x), y: Number(sprite.rect.y), width: Number(sprite.rect.width), height: Number(sprite.rect.height),
        };
        add(sprite.internalID, String(sprite.name), rect, pivotOf(sprite.alignment, sprite.pivot), sprite.border);
      }
    } else {
      const rect = { x: 0, y: 0, width: size.width, height: size.height };
      add(SINGLE_SPRITE_FILE_ID, path.basename(file, path.extname(file)), rect, pivotOf(importer.alignment, importer.spritePivot), importer.spriteBorder);
    }
  }

  asset(guid) {
    return this.byGuid.get(String(guid)) ?? null;
  }

  // The sprite a reference ({fileID, guid}) names, or null.
  sprite(reference) {
    if (!reference || !reference.guid) return null;
    return this.sprites.get(refKey(reference.guid, reference.fileID)) ?? null;
  }

  // The documents of a scene, prefab or asset file, by file id.
  load(file) {
    if (!this.documents.has(file)) {
      const map = new Map();
      for (const document of parseDocuments(fs.readFileSync(file, "utf8"))) map.set(document.fileId, document);
      this.documents.set(file, map);
    }
    return this.documents.get(file);
  }

  // The file a reference points at, or `file` itself for a local reference.
  fileOf(reference, file) {
    if (reference?.guid) return this.asset(reference.guid)?.file ?? null;
    return file;
  }

  // The class name of a MonoBehaviour document's script.
  scriptName(document) {
    const script = document?.data?.m_Script;
    return script?.guid ? this.scriptNames.get(String(script.guid)) ?? null : null;
  }
}

module.exports = { UnityProject, refKey, imageSize, SINGLE_SPRITE_FILE_ID };
