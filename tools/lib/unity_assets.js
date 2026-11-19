"use strict";
// Godot resources written from a Unity project's assets for
// tools/import_unity.js: copied files, an AtlasTexture per sprite (with its
// pivot as `metadata/pivot`), the TileSet that every converted tilemap shares
// and AnimationLibrary resources made from animation clips and controllers.
const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");
const { GodotFile, raw, num, quote, rect2, vec2, vec2i, name } = require("./godot_text");

function safeName(text) {
  return String(text).replace(/[\\/:*?"<>|]/g, "_").trim() || "unnamed";
}

// A fully transparent RGBA PNG of `size` x `size` pixels.
function transparentPng(size) {
  const crcTable = Array.from({ length: 256 }, (_unused, n) => {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (buffer) => {
    let c = 0xffffffff;
    for (const byte of buffer) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const sum = Buffer.alloc(4);
    sum.writeUInt32BE(crc(body));
    return Buffer.concat([length, body, sum]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(size, 0);
  header.writeUInt32BE(size, 4);
  header.set([8, 6, 0, 0, 0], 8);
  const rows = Buffer.alloc(size * (size * 4 + 1));
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", header),
    chunk("IDAT", zlib.deflateSync(rows)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

class AssetWriter {
  // `gameDir`: absolute games/<id>; `destination`: the import directory
  // relative to it (game/unity).
  constructor(project, gameDir, destination, pixelsPerUnit, paths = {}) {
    this.project = project;
    // Prefix of a path under Assets/ -> where it goes under the destination,
    // the longest prefix first.
    this.paths = Object.entries(paths).sort((a, b) => b[0].length - a[0].length);
    this.gameDir = gameDir;
    this.destination = destination;
    this.resRoot = `res://${destination}`;
    this.pixelsPerUnit = pixelsPerUnit;
    this.copied = new Map();
    this.atlases = new Map();
    this.warnings = new Set();
  }

  // Where a file under Assets/ (or its relative path) goes, relative to the
  // destination, through the configured path prefixes.
  outPath(fileOrRelative) {
    const relative = path.isAbsolute(fileOrRelative)
      ? path.relative(this.project.assets, fileOrRelative).split(path.sep).join("/")
      : fileOrRelative;
    for (const [from, to] of this.paths) {
      if (relative === from || relative.startsWith(`${from}/`)) return `${to}${relative.slice(from.length)}`.replace(/^\//, "");
    }
    return relative;
  }

  absolute(resPath) {
    return path.join(this.gameDir, resPath.replace(/^res:\/\//, ""));
  }

  write(resPath, text) {
    const file = this.absolute(resPath);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, text);
  }

  // The res:// path of a Unity asset file, copied on first use. `rename`
  // gives the copy another extension (an audio file compressed on copy).
  assetPath(file, rename = null) {
    if (this.copied.has(file)) return this.copied.get(file);
    const relative = this.outPath(file);
    const target = `${this.resRoot}/${rename ? relative.replace(/\.[^.]+$/, rename.extension) : relative}`;
    const absolute = this.absolute(target);
    fs.mkdirSync(path.dirname(absolute), { recursive: true });
    if (rename) rename.convert(file, absolute);
    else fs.copyFileSync(file, absolute);
    this.copied.set(file, target);
    return target;
  }

  // The res:// path of the AtlasTexture of a sprite from the project's
  // catalog, written on first use.
  atlas(sprite) {
    const key = `${sprite.guid}:${sprite.fileId}`;
    if (this.atlases.has(key)) return this.atlases.get(key);
    const texture = this.assetPath(sprite.file);
    const relative = this.outPath(sprite.file).replace(/\.[^.]+$/, "");
    const single = sprite.region.width === sprite.textureWidth && sprite.region.height === sprite.textureHeight;
    const resPath = single
      ? `${this.resRoot}/${relative}.tres`
      : `${this.resRoot}/${relative}/${safeName(sprite.name)}.tres`;
    const file = new GodotFile("gd_resource", { type: "AtlasTexture" });
    file.section("[resource]", [
      ["atlas", file.extResource("Texture2D", texture)],
      ["region", rect2(sprite.region.x, sprite.region.y, sprite.region.width, sprite.region.height)],
      ["filter_clip", true],
      ["metadata/pivot", vec2(sprite.pivot.x, sprite.pivot.y)],
      ["metadata/pixels_per_unit", sprite.pixelsPerUnit],
      ...(sprite.border ? [["metadata/border", raw(`Vector4i(${sprite.border.join(", ")})`)]] : []),
    ]);
    this.write(resPath, file.toString());
    this.atlases.set(key, resPath);
    return resPath;
  }

  atlasFor(reference) {
    const sprite = this.project.sprite(reference);
    return sprite ? this.atlas(sprite) : null;
  }

  warn(message) {
    this.warnings.add(message);
  }
}

// The TileSet shared by every tilemap of the import: one atlas source per
// texture for the sprites that sit on the cell grid, and a source of its own
// for each sprite that does not; plus a transparent collision tile.
class TileSetBuilder {
  constructor(assets, cellSize) {
    this.assets = assets;
    this.cell = cellSize;
    this.sources = [];
    this.byTexture = new Map();
    this.tiles = new Map();
    this.collision = null;
  }

  source(texture, regionSize, margins) {
    const entry = { id: this.sources.length, texture, regionSize, margins, tiles: new Map(), occupied: new Set() };
    this.sources.push(entry);
    return entry;
  }

  // { source, coords: [x, y], alternative } of `sprite` drawn with these flips.
  tileFor(sprite, flipH = false, flipV = false, transpose = false) {
    const key = `${sprite.guid}:${sprite.fileId}`;
    let tile = this.tiles.get(key);
    if (!tile) {
      tile = this.placeTile(sprite);
      this.tiles.set(key, tile);
    }
    // Alternative 0 is the plain tile; Godot transforms only the others.
    const flags = (flipH ? 1 : 0) | (flipV ? 2 : 0) | (transpose ? 4 : 0);
    if (!tile.alternatives.has(flags)) tile.alternatives.set(flags, tile.alternatives.size);
    return { source: tile.source.id, coords: tile.coords, alternative: tile.alternatives.get(flags) };
  }

  placeTile(sprite) {
    const { region } = sprite;
    const cell = this.cell;
    const scale = this.assets.pixelsPerUnit / sprite.pixelsPerUnit;
    if (Math.abs(scale - 1) > 1e-6) this.assets.warn(`sprite ${sprite.name} has ${sprite.pixelsPerUnit} pixels per unit, the grid ${this.assets.pixelsPerUnit}: drawn at its own size`);
    const origin = [Math.round(sprite.pivot.x - region.width / 2), Math.round(sprite.pivot.y - region.height / 2)];
    const aligned = region.x % cell === 0 && region.y % cell === 0 && region.width % cell === 0 && region.height % cell === 0;
    if (aligned) {
      let source = this.byTexture.get(sprite.file);
      if (!source) {
        source = this.source(sprite.file, [cell, cell], [0, 0]);
        this.byTexture.set(sprite.file, source);
      }
      const coords = [region.x / cell, region.y / cell];
      const size = [region.width / cell, region.height / cell];
      const cells = [];
      for (let x = 0; x < size[0]; x += 1) for (let y = 0; y < size[1]; y += 1) cells.push(`${coords[0] + x},${coords[1] + y}`);
      if (!cells.some((key) => source.occupied.has(key))) {
        cells.forEach((key) => source.occupied.add(key));
        const tile = { source, coords, size, origin, alternatives: new Map([[0, 0]]) };
        source.tiles.set(coords.join(","), tile);
        return tile;
      }
    }
    const source = this.source(sprite.file, [region.width, region.height], [region.x, region.y]);
    const tile = { source, coords: [0, 0], size: [1, 1], origin, alternatives: new Map([[0, 0]]) };
    source.tiles.set("0,0", tile);
    return tile;
  }

  // { source, coords, alternative } of the invisible tile that only collides.
  collisionTile() {
    if (!this.collision) {
      const resPath = `${this.assets.resRoot}/tiles/collision_cell.png`;
      this.assets.write(resPath, transparentPng(this.cell));
      const source = this.source(null, [this.cell, this.cell], [0, 0]);
      source.resPath = resPath;
      const tile = { source, coords: [0, 0], size: [1, 1], origin: [0, 0], alternatives: new Map([[0, 0]]), collides: true };
      source.tiles.set("0,0", tile);
      this.collision = tile;
    }
    return { source: this.collision.source.id, coords: [0, 0], alternative: 0 };
  }

  toString() {
    const file = new GodotFile("gd_resource", { type: "TileSet" });
    const sourceRefs = [];
    const half = this.cell / 2;
    for (const source of this.sources) {
      const texturePath = source.resPath ?? this.assets.assetPath(source.texture);
      const properties = [
        ["texture", file.extResource("Texture2D", texturePath)],
        ["margins", vec2i(source.margins[0], source.margins[1])],
        ["texture_region_size", vec2i(source.regionSize[0], source.regionSize[1])],
      ];
      for (const tile of source.tiles.values()) {
        const at = `${tile.coords[0]}:${tile.coords[1]}`;
        if (tile.size[0] !== 1 || tile.size[1] !== 1) properties.push([`${at}/size_in_atlas`, vec2i(tile.size[0], tile.size[1])]);
        for (const [flags, alternative] of [...tile.alternatives.entries()].sort((a, b) => a[1] - b[1])) {
          properties.push([`${at}/${alternative}`, alternative]);
          if (tile.origin[0] || tile.origin[1]) properties.push([`${at}/${alternative}/texture_origin`, vec2i(tile.origin[0], tile.origin[1])]);
          if (flags & 1) properties.push([`${at}/${alternative}/flip_h`, true]);
          if (flags & 2) properties.push([`${at}/${alternative}/flip_v`, true]);
          if (flags & 4) properties.push([`${at}/${alternative}/transpose`, true]);
          if (tile.collides) {
            properties.push([`${at}/${alternative}/physics_layer_0/polygon_0/points`, raw(`PackedVector2Array(${-half}, ${-half}, ${half}, ${-half}, ${half}, ${half}, ${-half}, ${half})`)]);
          }
        }
      }
      sourceRefs.push([source.id, file.subResource("TileSetAtlasSource", properties, "Source")]);
    }
    const resource = [["tile_size", vec2i(this.cell, this.cell)]];
    if (this.collision) resource.push(["physics_layer_0/collision_layer", 1]);
    for (const [id, reference] of sourceRefs) resource.push([`sources/${id}`, reference]);
    file.section("[resource]", resource);
    return file.toString();
  }
}

// Writes the tilemap layers' cells as the PackedByteArray of TileMapLayer.tile_map_data.
function tileMapData(cells) {
  const buffer = Buffer.alloc(2 + cells.length * 12);
  buffer.writeUInt16LE(0, 0);
  cells.forEach((cell, index) => {
    const offset = 2 + index * 12;
    buffer.writeInt16LE(cell.x, offset);
    buffer.writeInt16LE(cell.y, offset + 2);
    buffer.writeUInt16LE(cell.source, offset + 4);
    buffer.writeUInt16LE(cell.coords[0], offset + 6);
    buffer.writeUInt16LE(cell.coords[1], offset + 8);
    buffer.writeUInt16LE(cell.alternative, offset + 10);
  });
  return raw(`PackedByteArray("${buffer.toString("base64")}")`);
}

const floats = (list) => raw(`PackedFloat32Array(${list.map(num).join(", ")})`);

module.exports = { AssetWriter, TileSetBuilder, tileMapData, floats, safeName, transparentPng, name, quote };
