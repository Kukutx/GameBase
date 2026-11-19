"use strict";
// Converts a resolved Unity scene or prefab tree (tools/lib/unity_scene.js)
// into a Godot scene for tools/import_unity.js.
//
// Units become pixels (`pixels_per_unit`) with y pointing down. A game object
// with a SpriteRenderer becomes a Sprite2D whose pivot sits on the node, one
// with a Tilemap a TileMapLayer of the shared TileSet, any other a Node2D.
// Sorting layers become absolute z indices, the layer that sorts by y
// (`y_sort_layer`) sorting by y like Unity's custom axis, and a SortingGroup
// keeps its children together at the group's place. Colliders become a
// StaticBody2D (an Area2D for triggers) below the object, an Animator an
// AnimationPlayer with the controller's library. A MonoBehaviour that the
// game maps (`scripts`) replaces its whole object with an instance of the
// game's scene, its fields set on that instance's properties.
const { GodotFile, raw, num, vec2, quote } = require("./godot_text");
const { tileMapData } = require("./unity_assets");
const { spriteOffset } = require("./unity_animation");

const SCRIPT_CLASS = 114;

function sanitize(text) {
  return String(text).replace(/[.:@/"%]/g, "_").trim() || "Node";
}

// The flips and transposition of a Godot tile that draw a sprite as Unity's
// tile matrix does. Unity's matrix maps sprite space (y up) to the cell; the
// same map in Godot's y-down space negates the off-diagonal terms. Godot
// transposes a tile first, then flips it.
function tileFlags(matrix) {
  const a = Math.round(Number(matrix.e00 ?? 1));
  const b = -Math.round(Number(matrix.e01 ?? 0));
  const c = -Math.round(Number(matrix.e10 ?? 0));
  const d = Math.round(Number(matrix.e11 ?? 1));
  for (const transpose of [false, true]) {
    for (const flipH of [false, true]) {
      for (const flipV of [false, true]) {
        const t = transpose ? [0, 1, 1, 0] : [1, 0, 0, 1];
        const m = [t[0] * (flipH ? -1 : 1), t[1] * (flipH ? -1 : 1), t[2] * (flipV ? -1 : 1), t[3] * (flipV ? -1 : 1)];
        if (m[0] === a && m[1] === b && m[2] === c && m[3] === d) return [flipH, flipV, transpose];
      }
    }
  }
  return [a < 0, d < 0, false];
}

function quaternionAngle(rotation) {
  if (!rotation) return 0;
  return -2 * Math.atan2(Number(rotation.z ?? 0), Number(rotation.w ?? 1));
}

class SceneConverter {
  // `options`: { pixelsPerUnit, sortingLayers: Map(uniqueID -> index),
  // ySortIndex, scripts, skipObjects, locationIds, libraries(controllerFile) }
  constructor(project, assets, tileset, options) {
    this.project = project;
    this.assets = assets;
    this.tileset = tileset;
    this.options = options;
    this.ppu = options.pixelsPerUnit;
  }

  zIndex(layerId, order) {
    // Unity writes the ids as signed or unsigned 32-bit ints.
    const index = this.options.sortingLayers.get(String(Number(layerId ?? 0) >>> 0)) ?? 0;
    const z = (index - this.options.ySortIndex) * 200 + Math.max(-99, Math.min(99, Number(order ?? 0)));
    return Math.max(-4096, Math.min(4096, z));
  }

  point(vector) {
    return [Number(vector?.x ?? 0) * this.ppu, -Number(vector?.y ?? 0) * this.ppu];
  }

  // `options.prefab`: a prefab keeps its own objects, so only scripts mapped
  // with `attach` apply to it (see mappingFor).
  convert(roots, rootName, options = {}) {
    this.prefab = Boolean(options.prefab);
    const file = new GodotFile("gd_scene");
    file.section(`[node name=${quote(sanitize(rootName))} type="Node2D"]`, [["y_sort_enabled", true]]);
    const used = new Map();
    for (const node of roots) this.emit(file, node, ".", used, false);
    return file.toString();
  }

  uniqueName(used, parent, wanted) {
    const key = `${parent}|${wanted}`;
    const count = used.get(key) ?? 0;
    used.set(key, count + 1);
    return count === 0 ? wanted : `${wanted}_${count + 1}`;
  }

  transformProperties(node) {
    const transform = node.transform ?? {};
    const [x, y] = this.point(transform.m_LocalPosition);
    const properties = [];
    if (x || y) properties.push(["position", vec2(x, y)]);
    const rotation = quaternionAngle(transform.m_LocalRotation);
    if (Math.abs(rotation) > 1e-6) properties.push(["rotation", rotation]);
    const scaleX = Number(transform.m_LocalScale?.x ?? 1);
    const scaleY = Number(transform.m_LocalScale?.y ?? 1);
    if (scaleX !== 1 || scaleY !== 1) properties.push(["scale", vec2(scaleX, scaleY)]);
    return properties;
  }

  emit(file, node, parent, used, inGroup) {
    if ((this.options.skipObjects ?? []).includes(node.name)) return;
    const name = this.uniqueName(used, parent, sanitize(node.name));
    const here = parent === "." ? name : `${parent}/${name}`;
    const byType = (type) => node.components.find((component) => component.type === type);
    // The game's mapping of this object's scripts, the first in the config's order.
    const mappedAll = Object.keys(this.options.scripts ?? {})
      .map((script) => [script, node.components.find((component) => component.classId === SCRIPT_CLASS && component.script === script)])
      .map(([script, component]) => [this.mappingFor(script), component])
      .filter(([mapping, component]) => mapping && component);
    const replacing = mappedAll.find(([mapping]) => !mapping.attach);
    if (replacing) {
      this.emitMapped(file, node, replacing[1], replacing[0], name, parent);
      return;
    }
    const attached = mappedAll.find(([mapping]) => mapping.attach);
    const properties = this.transformProperties(node);
    if (!node.active) properties.push(["visible", false]);
    let type = "Node2D";
    const renderer = byType("SpriteRenderer");
    const tilemap = byType("Tilemap");
    const group = byType("SortingGroup");
    if (tilemap) {
      type = "TileMapLayer";
      this.tilemapProperties(file, node, tilemap, properties);
    } else if (renderer) {
      type = "Sprite2D";
      this.spriteProperties(file, renderer, properties, inGroup);
    } else if (!group && !inGroup) {
      properties.push(["y_sort_enabled", true]);
    }
    if (group) {
      properties.push(["z_index", this.zIndex(group.data.m_SortingLayerID, group.data.m_SortingOrder)]);
      properties.push(["z_as_relative", false]);
    }
    if (attached) {
      const [mapping, component] = attached;
      properties.push(["script", file.extResource("Script", mapping.attach)]);
      properties.push(...this.mappedProperties(file, component, mapping, node.name));
    }
    file.section(`[node name=${quote(name)} type="${type}" parent=${quote(parent)}]`, properties);
    if (tilemap && byType("TilemapCollider2D")) this.emitTileCollision(file, node, tilemap, here);
    this.emitColliders(file, node, here);
    const animator = byType("Animator");
    if (animator) this.emitAnimator(file, animator, here);
    let children = node.children;
    if (group || inGroup) {
      const order = (child) => Number(child.components.find((component) => component.type === "SpriteRenderer")?.data?.m_SortingOrder ?? 0);
      children = [...children].sort((a, b) => order(a) - order(b));
    }
    for (const child of children) this.emit(file, child, here, used, inGroup || Boolean(group));
  }

  spriteProperties(file, renderer, properties, inGroup) {
    const data = renderer.data;
    const sprite = this.project.sprite(data.m_Sprite);
    const flipH = Number(data.m_FlipX ?? 0) === 1;
    const flipV = Number(data.m_FlipY ?? 0) === 1;
    if (sprite) {
      properties.push(["texture", file.extResource("Texture2D", this.assets.atlas(sprite))]);
      properties.push(["centered", false]);
      const [x, y] = spriteOffset(sprite, flipH, flipV);
      properties.push(["offset", vec2(x, y)]);
    }
    if (flipH) properties.push(["flip_h", true]);
    if (flipV) properties.push(["flip_v", true]);
    const color = data.m_Color;
    if (color && (Number(color.r) !== 1 || Number(color.g) !== 1 || Number(color.b) !== 1 || Number(color.a) !== 1)) {
      properties.push(["self_modulate", raw(`Color(${num(color.r)}, ${num(color.g)}, ${num(color.b)}, ${num(color.a)})`)]);
    }
    if (Number(data.m_Enabled ?? 1) === 0) properties.push(["visible", false]);
    if (Number(data.m_DrawMode ?? 0) !== 0) this.assets.warn(`sprite renderer with draw mode ${data.m_DrawMode} drawn simple`);
    if (!inGroup) {
      properties.push(["z_index", this.zIndex(data.m_SortingLayerID, data.m_SortingOrder)]);
      properties.push(["z_as_relative", false]);
    }
  }

  tilemapProperties(file, node, tilemap, properties) {
    const renderer = node.components.find((component) => component.type === "TilemapRenderer");
    const data = tilemap.data;
    const visible = !renderer || Number(renderer.data.m_Enabled ?? 1) !== 0;
    const cells = [];
    if (visible) {
      for (const entry of Array.isArray(data.m_Tiles) ? data.m_Tiles : []) {
        const tile = entry.second ?? {};
        const spriteRef = data.m_TileSpriteArray?.[Number(tile.m_TileSpriteIndex)]?.m_Data;
        const sprite = this.project.sprite(spriteRef);
        if (!sprite) continue;
        const matrix = data.m_TileMatrixArray?.[Number(tile.m_TileMatrixIndex)]?.m_Data ?? {};
        const [flipH, flipV, transposed] = tileFlags(matrix);
        const placed = this.tileset.tileFor(sprite, flipH, flipV, transposed);
        cells.push({ x: Number(entry.first.x), y: -Number(entry.first.y) - 1, ...placed });
      }
    }
    properties.push(["tile_map_data", tileMapData(cells)]);
    properties.push(["tile_set", file.extResource("TileSet", this.options.tilesetPath)]);
    if (renderer) {
      const z = this.zIndex(renderer.data.m_SortingLayerID, renderer.data.m_SortingOrder);
      properties.push(["z_index", z]);
      properties.push(["z_as_relative", false]);
      if (this.options.sortingLayers.get(String(renderer.data.m_SortingLayerID ?? 0)) === this.options.ySortIndex) properties.push(["y_sort_enabled", true]);
    }
  }

  emitTileCollision(file, node, tilemap, here) {
    const cells = [];
    const placed = this.tileset.collisionTile();
    for (const entry of Array.isArray(tilemap.data.m_Tiles) ? tilemap.data.m_Tiles : []) cells.push({ x: Number(entry.first.x), y: -Number(entry.first.y) - 1, ...placed });
    file.section(`[node name="Collision" type="TileMapLayer" parent=${quote(here)}]`, [
      ["tile_map_data", tileMapData(cells)],
      ["tile_set", file.extResource("TileSet", this.options.tilesetPath)],
    ]);
  }

  emitColliders(file, node, here) {
    const colliders = node.components.filter((component) => /Collider2D$/.test(component.type) && !/^(Tilemap|Composite)/.test(component.type));
    if (colliders.length === 0) return;
    const groups = [
      ["Body", "StaticBody2D", colliders.filter((collider) => Number(collider.data.m_IsTrigger ?? 0) === 0)],
      ["Trigger", "Area2D", colliders.filter((collider) => Number(collider.data.m_IsTrigger ?? 0) !== 0)],
    ];
    for (const [bodyName, bodyType, list] of groups) {
      if (list.length === 0) continue;
      const bodyPath = `${here}/${bodyName}`;
      file.section(`[node name="${bodyName}" type="${bodyType}" parent=${quote(here)}]`, []);
      list.forEach((collider, index) => this.emitShape(file, collider, bodyPath, `Shape${index + 1}`));
    }
  }

  emitShape(file, collider, parent, name) {
    const data = collider.data;
    const [offsetX, offsetY] = this.point(data.m_Offset);
    const position = offsetX || offsetY ? [["position", vec2(offsetX, offsetY)]] : [];
    if (Number(data.m_Enabled ?? 1) === 0) position.push(["disabled", true]);
    if (collider.type === "BoxCollider2D") {
      const shape = file.subResource("RectangleShape2D", [["size", vec2(Number(data.m_Size?.x ?? 1) * this.ppu, Number(data.m_Size?.y ?? 1) * this.ppu)]], "Rect");
      file.section(`[node name="${name}" type="CollisionShape2D" parent=${quote(parent)}]`, [...position, ["shape", shape]]);
    } else if (collider.type === "CircleCollider2D") {
      const shape = file.subResource("CircleShape2D", [["radius", Number(data.m_Radius ?? 0.5) * this.ppu]], "Circle");
      file.section(`[node name="${name}" type="CollisionShape2D" parent=${quote(parent)}]`, [...position, ["shape", shape]]);
    } else if (collider.type === "CapsuleCollider2D") {
      const width = Number(data.m_Size?.x ?? 1) * this.ppu;
      const height = Number(data.m_Size?.y ?? 1) * this.ppu;
      const horizontal = Number(data.m_Direction ?? 0) === 1;
      const shape = file.subResource("CapsuleShape2D", [["radius", (horizontal ? height : width) / 2], ["height", horizontal ? width : height]], "Capsule");
      const rotation = horizontal ? [["rotation", Math.PI / 2]] : [];
      file.section(`[node name="${name}" type="CollisionShape2D" parent=${quote(parent)}]`, [...position, ...rotation, ["shape", shape]]);
    } else if (collider.type === "PolygonCollider2D") {
      (data.m_Points?.m_Paths ?? []).forEach((points, index) => {
        const polygon = points.map((point) => this.point(point).map(num).join(", ")).join(", ");
        file.section(`[node name="${name}${index ? `_${index + 1}` : ""}" type="CollisionPolygon2D" parent=${quote(parent)}]`, [...position, ["polygon", raw(`PackedVector2Array(${polygon})`)]]);
      });
    } else if (collider.type === "EdgeCollider2D") {
      const points = (data.m_Points ?? []).map((point) => this.point(point).map(num).join(", ")).join(", ");
      file.section(`[node name="${name}" type="CollisionPolygon2D" parent=${quote(parent)}]`, [...position, ["build_mode", 1], ["polygon", raw(`PackedVector2Array(${points})`)]]);
    } else {
      this.assets.warn(`${collider.type} is not converted`);
    }
  }

  emitAnimator(file, animator, here) {
    const controller = animator.data.m_Controller;
    const controllerFile = controller?.guid ? this.project.asset(controller.guid)?.file : null;
    if (!controllerFile) return;
    const library = this.options.libraries(controllerFile);
    const properties = [
      ["root_node", raw('NodePath("..")')],
      ["libraries", raw(`{\n&"": ${file.extResource("AnimationLibrary", library.path).text}\n}`)],
    ];
    if (library.defaultClip) properties.push(["autoplay", library.defaultClip]);
    file.section(`[node name="AnimationPlayer" type="AnimationPlayer" parent=${quote(here)}]`, properties);
  }

  // The mapping of a script in the scene or prefab being converted: a
  // mapping's `prefab` entry replaces it in prefabs (false: none there), and
  // only mappings that attach a script apply to prefabs.
  mappingFor(script) {
    const mapping = this.options.scripts?.[script];
    if (!mapping || !this.prefab) return mapping ?? null;
    if (mapping.prefab === false) return null;
    const effective = mapping.prefab && typeof mapping.prefab === "object" ? mapping.prefab : mapping;
    return effective.attach ? effective : null;
  }

  // The properties a mapping sets from a component's fields ("a.b" reads a
  // nested field), then its fixed values, then those of `by_name` for the
  // first object name prefix that matches.
  mappedProperties(file, component, mapping, objectName = "") {
    const properties = [];
    for (const [field, [property, kind]] of Object.entries(mapping.properties ?? {})) {
      const value = field.split(".").reduce((data, key) => (data && typeof data === "object" ? data[key] : undefined), component.data);
      if (value === undefined) continue;
      const converted = this.convertField(file, value, kind);
      if (converted !== undefined) properties.push([property, converted]);
    }
    for (const [property, value] of Object.entries(mapping.set ?? {})) properties.push([property, raw(String(value))]);
    const named = Object.entries(mapping.by_name ?? {}).find(([prefix]) => String(objectName).startsWith(prefix));
    for (const [property, value] of Object.entries(named?.[1] ?? {})) properties.push([property, raw(String(value))]);
    return properties;
  }

  emitMapped(file, node, component, mapping, name, parent) {
    const properties = [...this.transformProperties(node), ...this.mappedProperties(file, component, mapping, node.name)];
    // Fields of the object's other components the mapping reads too.
    for (const [type, fields] of Object.entries(mapping.components ?? {})) {
      const other = node.components.find((entry) => entry.type === type || entry.script === type);
      if (other) properties.push(...this.mappedProperties(file, other, { properties: fields }));
    }
    file.section(`[node name=${quote(name)} parent=${quote(parent)} instance=${file.extResource("PackedScene", mapping.scene).text}]`, properties);
  }

  convertField(file, value, kind) {
    switch (kind) {
      case "int":
        return raw(String(Math.round(Number(value))));
      case "float":
        return Number(value);
      case "bool":
        return Number(value) === 1;
      case "string":
        return String(value ?? "");
      case "id":
        return raw(`&${quote(String(value ?? ""))}`);
      case "location": {
        const id = this.options.locationIds?.[String(value)] ?? String(value);
        return raw(`&${quote(id)}`);
      }
      case "position": {
        const [x, y] = this.point(value);
        return vec2(x, y);
      }
      case "cell":
        return raw(`Vector2i(${Math.round(Number(value?.x ?? 0))}, ${-Math.round(Number(value?.y ?? 0)) - 1})`);
      case "asset": {
        const asset = value?.guid ? this.project.asset(value.guid) : null;
        return asset ? raw(`&${quote(asset.relative.split("/").pop().replace(/\.[^.]+$/, ""))}`) : undefined;
      }
      case "sprite": {
        const atlas = this.assets.atlasFor(value);
        return atlas ? file.extResource("Texture2D", atlas) : undefined;
      }
      default:
        if (String(kind).startsWith("map:")) {
          const table = this.options.idMaps?.[String(kind).slice(4)] ?? {};
          // 0 and empty are Unity's "none".
          if (value === null || value === "" || Number(value) === 0) return undefined;
          const id = table[String(value)];
          if (id === undefined) {
            this.assets.warn(`no ${kind} id for ${value}`);
            return undefined;
          }
          return raw(`&${quote(id)}`);
        }
        this.assets.warn(`unknown field kind ${kind}`);
        return undefined;
    }
  }
}

module.exports = { SceneConverter, sanitize };
