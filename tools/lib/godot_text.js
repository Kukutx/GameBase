"use strict";
// Writes Godot 4 text resources (.tres) and scenes (.tscn) in the shape this
// repository keeps (.agents/rules/scenes-resources.md): readable ids, `path=`
// references without uid, `load_steps` counted, children after parents.

class Raw {
  constructor(text) {
    this.text = text;
  }
}

const raw = (text) => new Raw(text);

function num(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return "0";
  const rounded = Math.round(number * 1e6) / 1e6;
  return Object.is(rounded, -0) ? "0" : String(rounded);
}

function quote(text) {
  return `"${String(text).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
}

function value(item) {
  if (item instanceof Raw) return item.text;
  if (item === null || item === undefined) return "null";
  if (typeof item === "boolean") return item ? "true" : "false";
  if (typeof item === "number") return num(item);
  if (typeof item === "string") return quote(item);
  if (Array.isArray(item)) return `[${item.map(value).join(", ")}]`;
  if (typeof item === "object") {
    const entries = Object.entries(item).map(([key, entry]) => `${quote(key)}: ${value(entry)}`);
    return entries.length === 0 ? "{}" : `{\n${entries.join(",\n")}\n}`;
  }
  return String(item);
}

const vec2 = (x, y) => raw(`Vector2(${num(x)}, ${num(y)})`);
const vec2i = (x, y) => raw(`Vector2i(${Math.round(x)}, ${Math.round(y)})`);
const rect2 = (x, y, w, h) => raw(`Rect2(${num(x)}, ${num(y)}, ${num(w)}, ${num(h)})`);
const color = (r, g, b, a = 1) => raw(`Color(${num(r)}, ${num(g)}, ${num(b)}, ${num(a)})`);
const name = (text) => raw(`&${quote(text)}`);
const nodePath = (text) => raw(`NodePath(${quote(text)})`);

// A .tres or .tscn being built: its external and internal resources and its
// body sections.
class GodotFile {
  constructor(kind, header = {}) {
    this.kind = kind;
    this.header = header;
    this.ext = [];
    this.extByPath = new Map();
    this.sub = [];
    this.sections = [];
  }

  extResource(type, resPath) {
    if (!this.extByPath.has(resPath)) {
      const base = resPath.split("/").pop().replace(/\.[^.]+$/, "").replace(/[^A-Za-z0-9_]/g, "_").slice(0, 40);
      const id = `${this.ext.length + 1}_${base}`;
      this.ext.push({ type, path: resPath, id });
      this.extByPath.set(resPath, id);
    }
    return raw(`ExtResource("${this.extByPath.get(resPath)}")`);
  }

  // Adds an internal resource; `properties` is a list of [key, value] or an object.
  subResource(type, properties, hint = type) {
    const id = `${hint}_${this.sub.length + 1}`;
    this.sub.push({ type, id, properties });
    return raw(`SubResource("${id}")`);
  }

  section(header, properties) {
    this.sections.push({ header, properties });
  }

  toString() {
    const lines = [];
    const steps = this.ext.length + this.sub.length + 1;
    const attributes = Object.entries(this.header).map(([key, entry]) => `${key}=${quote(entry)}`);
    lines.push(`[${[this.kind, ...attributes, `load_steps=${steps}`, "format=3"].join(" ")}]`, "");
    for (const entry of this.ext) lines.push(`[ext_resource type="${entry.type}" path="${entry.path}" id="${entry.id}"]`);
    if (this.ext.length) lines.push("");
    for (const entry of this.sub) {
      lines.push(`[sub_resource type="${entry.type}" id="${entry.id}"]`);
      lines.push(...propertyLines(entry.properties), "");
    }
    for (const entry of this.sections) {
      lines.push(entry.header);
      lines.push(...propertyLines(entry.properties), "");
    }
    return lines.join("\n").replace(/\n+$/, "\n");
  }
}

function propertyLines(properties) {
  const pairs = Array.isArray(properties) ? properties : Object.entries(properties ?? {});
  return pairs.filter(([, entry]) => entry !== undefined).map(([key, entry]) => `${key} = ${value(entry)}`);
}

module.exports = { GodotFile, raw, value, num, quote, vec2, vec2i, rect2, color, name, nodePath };
