"use strict";
// Reads the YAML that the Unity editor writes for scenes, prefabs, assets,
// animation clips, controllers and .meta files. Unity writes a small, regular
// subset of YAML 1.1: block mappings, sequences whose dashes may sit at the
// indentation of their key, flow mappings of plain scalars (references such as
// {fileID: 1, guid: ..., type: 3}), double-quoted strings with \u escapes,
// single-quoted strings and plain scalars that wrap onto deeper-indented lines.
// A file holds one or more documents, each headed `--- !u!<classID> &<fileID>`
// (with ` stripped` for objects that live in a prefab).

function parseScalar(text) {
  const value = text.trim();
  if (value === "") return null;
  if (value.startsWith('"')) return parseDoubleQuoted(value);
  if (value.startsWith("'")) return value.slice(1, value.endsWith("'") ? -1 : undefined).replace(/''/g, "'");
  if (value.startsWith("{")) return parseFlowMapping(value);
  if (value.startsWith("[")) return parseFlowSequence(value);
  // Unity writes an int array as hex text, which may start with a zero: such
  // text stays text (see hexInts).
  if (/^0\d/.test(value)) return value;
  if (/^-?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/.test(value)) {
    const number = Number(value);
    // File ids are 64-bit: an integer JavaScript cannot hold exactly stays text.
    return /^-?\d+$/.test(value) && !Number.isSafeInteger(number) ? value : number;
  }
  return value;
}

// The ints of an int array Unity wrote as hex text (8 digits of a
// little-endian int32 each); a number is the text YAML read as one.
function hexInts(value) {
  if (Array.isArray(value)) return value.map(Number);
  if (value === null || value === undefined || value === "") return [];
  const text = typeof value === "number" ? String(value).padStart(8, "0") : String(value);
  const result = [];
  for (let index = 0; index + 8 <= text.length; index += 8) {
    result.push(Buffer.from(text.slice(index, index + 8), "hex").readInt32LE(0));
  }
  return result;
}

function parseDoubleQuoted(value) {
  let body = value.slice(1);
  if (body.endsWith('"')) body = body.slice(0, -1);
  return body.replace(/\\(u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|.)/g, (_match, code) => {
    if (code[0] === "u" || code[0] === "x") return String.fromCharCode(parseInt(code.slice(1), 16));
    return { n: "\n", t: "\t", r: "\r", "0": "\0", '"': '"', "\\": "\\", "/": "/", " ": " " }[code] ?? code;
  });
}

// Splits `a: 1, b: {c: 2}` at the commas that are not nested.
function splitFlow(body) {
  const parts = [];
  let depth = 0;
  let quote = "";
  let start = 0;
  for (let index = 0; index < body.length; index += 1) {
    const char = body[index];
    if (quote) {
      if (char === quote && body[index - 1] !== "\\") quote = "";
    } else if (char === '"' || char === "'") {
      quote = char;
    } else if (char === "{" || char === "[") {
      depth += 1;
    } else if (char === "}" || char === "]") {
      depth -= 1;
    } else if (char === "," && depth === 0) {
      parts.push(body.slice(start, index));
      start = index + 1;
    }
  }
  if (body.slice(start).trim() !== "") parts.push(body.slice(start));
  return parts;
}

function parseFlowMapping(value) {
  const result = {};
  const body = value.trim().slice(1, -1);
  for (const part of splitFlow(body)) {
    const colon = part.indexOf(":");
    if (colon < 0) continue;
    result[part.slice(0, colon).trim()] = parseScalar(part.slice(colon + 1));
  }
  return result;
}

function parseFlowSequence(value) {
  const body = value.trim().slice(1, -1);
  return splitFlow(body).map((part) => parseScalar(part));
}

function indentOf(line) {
  return line.length - line.trimStart().length;
}

// Splits `key: value` (the key never holds ": " in Unity files).
function splitKey(text) {
  const match = /^("[^"]*"|[^:]+?):(?:\s+(.*))?$/.exec(text);
  if (!match) return null;
  return { key: match[1].replace(/^"|"$/g, ""), rest: match[2] ?? "" };
}

class Parser {
  constructor(lines) {
    this.lines = lines;
    this.index = 0;
  }

  peek() {
    while (this.index < this.lines.length && this.lines[this.index].trim() === "") this.index += 1;
    return this.index < this.lines.length ? this.lines[this.index] : null;
  }

  // A value that starts on `rest` and may continue on lines indented deeper
  // than `indent` (wrapped scalars and quoted strings).
  scalarWithContinuation(rest, indent) {
    let text = rest;
    const quoted = text.startsWith('"') || text.startsWith("'");
    const closed = () => quoted && text.length > 1 && text.endsWith(text[0]) && !text.endsWith("\\" + text[0]);
    while (this.index < this.lines.length) {
      const next = this.lines[this.index];
      if (next.trim() === "") {
        if (!quoted) break;
        text += "\n";
        this.index += 1;
        continue;
      }
      if (quoted ? closed() : indentOf(next) <= indent) break;
      if (!quoted && (next.trimStart().startsWith("- ") || splitKey(next.trim()))) break;
      text += (text.endsWith("\n") ? "" : " ") + next.trim();
      this.index += 1;
    }
    return parseScalar(text);
  }

  // A value after `key:` with nothing on the line: a nested block, an
  // indentless sequence at `indent`, or null.
  blockAfterKey(indent) {
    const next = this.peek();
    if (next === null) return null;
    const nextIndent = indentOf(next);
    const trimmed = next.trimStart();
    if (trimmed.startsWith("- ") || trimmed === "-") {
      if (nextIndent >= indent) return this.sequence(nextIndent);
      return null;
    }
    if (nextIndent > indent) return this.mapping(nextIndent);
    return null;
  }

  mapping(indent) {
    const result = {};
    for (;;) {
      const line = this.peek();
      if (line === null || indentOf(line) !== indent) break;
      const trimmed = line.trim();
      if (trimmed.startsWith("- ") || trimmed.startsWith("---")) break;
      const pair = splitKey(trimmed);
      this.index += 1;
      if (!pair) continue;
      result[pair.key] = pair.rest === "" ? this.blockAfterKey(indent) : this.scalarWithContinuation(pair.rest, indent);
    }
    return result;
  }

  sequence(indent) {
    const result = [];
    for (;;) {
      const line = this.peek();
      if (line === null || indentOf(line) !== indent) break;
      const trimmed = line.trim();
      if (!(trimmed.startsWith("- ") || trimmed === "-")) break;
      const itemText = trimmed === "-" ? "" : trimmed.slice(2);
      const itemIndent = indent + 2;
      if (itemText === "") {
        this.index += 1;
        result.push(this.blockAfterKey(indent));
        continue;
      }
      if (itemText.startsWith("- ") || itemText === "-") {
        // `- - x`: a sequence nested in a sequence item.
        this.lines[this.index] = " ".repeat(itemIndent) + itemText;
        result.push(this.sequence(itemIndent));
        continue;
      }
      const pair = itemText.startsWith("{") || itemText.startsWith('"') ? null : splitKey(itemText);
      if (!pair) {
        this.index += 1;
        result.push(this.scalarWithContinuation(itemText, indent));
        continue;
      }
      // `- key: value` opens a mapping whose keys sit at indent + 2: rewrite
      // the line in place so mapping() reads it like the keys below it.
      this.lines[this.index] = " ".repeat(itemIndent) + itemText;
      result.push(this.mapping(itemIndent));
    }
    return result;
  }
}

// Every document of a Unity YAML file: { classId, fileId, stripped, type, data }.
function parseDocuments(text) {
  const documents = [];
  const lines = text.replace(/\r\n?/g, "\n").split("\n");
  let header = null;
  let body = [];
  const flush = () => {
    if (header === null && body.every((line) => line.trim() === "" || line.startsWith("%"))) return;
    const content = body.filter((line) => !line.startsWith("%"));
    const parser = new Parser(content);
    const first = parser.peek();
    const data = first === null ? {} : parser.mapping(indentOf(first));
    const type = Object.keys(data)[0] ?? "";
    documents.push({ ...(header ?? { classId: 0, fileId: "0", stripped: false }), type, data: data[type] ?? data });
  };
  for (const line of lines) {
    const match = /^--- !u!(\d+) &(-?\d+)( stripped)?/.exec(line);
    if (match) {
      flush();
      header = { classId: Number(match[1]), fileId: match[2], stripped: Boolean(match[3]) };
      body = [];
    } else {
      body.push(line);
    }
  }
  flush();
  return documents;
}

// A .meta file or a single-document asset as a plain object.
function parseSingle(text) {
  const parser = new Parser(text.replace(/\r\n?/g, "\n").split("\n").filter((line) => !line.startsWith("%") && !line.startsWith("---")));
  const first = parser.peek();
  return first === null ? {} : parser.mapping(indentOf(first));
}

module.exports = { hexInts, parseDocuments, parseSingle, parseScalar };
