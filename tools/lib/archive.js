const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

const ZIP_MIN_EPOCH = 315532800; // 1980-01-01 UTC, the earliest date a ZIP entry can carry.
const S_IFREG = 0o100000;
const TAR_BLOCK = 512;

function dosDateTime(epoch) {
  const date = new Date(Math.max(epoch, ZIP_MIN_EPOCH) * 1000);
  const time = (date.getUTCHours() << 11) | (date.getUTCMinutes() << 5) | (date.getUTCSeconds() >> 1);
  const day = ((date.getUTCFullYear() - 1980) << 9) | ((date.getUTCMonth() + 1) << 5) | date.getUTCDate();
  return { time, day };
}

// entries: [{ name, data: Buffer, mode }] already in the order they should be stored.
function buildZip(entries, epoch) {
  const { time, day } = dosDateTime(epoch);
  const localParts = [];
  const centralParts = [];
  let offset = 0;
  for (const entry of entries) {
    const name = Buffer.from(entry.name, "utf8");
    const utf8Flag = /[^\x00-\x7f]/.test(entry.name) ? 0x0800 : 0;
    const compressed = zlib.deflateRawSync(entry.data, { level: 9 });
    const crc = zlib.crc32(entry.data);
    if (entry.data.length > 0xfffffffe || compressed.length > 0xfffffffe) {
      throw new Error(`ZIP64 is not supported: ${entry.name}`);
    }

    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(utf8Flag, 6);
    local.writeUInt16LE(8, 8);
    local.writeUInt16LE(time, 10);
    local.writeUInt16LE(day, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(compressed.length, 18);
    local.writeUInt32LE(entry.data.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28);
    localParts.push(local, name, compressed);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE((3 << 8) | 20, 4); // made on Unix so the mode bits are honoured
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(utf8Flag, 8);
    central.writeUInt16LE(8, 10);
    central.writeUInt16LE(time, 12);
    central.writeUInt16LE(day, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(compressed.length, 20);
    central.writeUInt32LE(entry.data.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt32LE(((S_IFREG | entry.mode) << 16) >>> 0, 38);
    central.writeUInt32LE(offset, 42);
    centralParts.push(central, name);

    offset += local.length + name.length + compressed.length;
  }
  if (entries.length > 0xfffe || offset > 0xfffffffe) {
    throw new Error("ZIP64 is not supported: archive too large");
  }
  const centralSize = centralParts.reduce((sum, part) => sum + part.length, 0);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralSize, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...localParts, ...centralParts, end]);
}

function readZipDirectory(handle, size) {
  const tailLength = Math.min(size, 0xffff + 22);
  const tail = Buffer.alloc(tailLength);
  fs.readSync(handle, tail, 0, tailLength, size - tailLength);
  let end = -1;
  for (let index = tailLength - 22; index >= 0; index -= 1) {
    if (tail.readUInt32LE(index) === 0x06054b50) {
      end = index;
      break;
    }
  }
  if (end < 0) {
    throw new Error("Not a ZIP archive: end of central directory not found");
  }
  const count = tail.readUInt16LE(end + 10);
  const centralSize = tail.readUInt32LE(end + 12);
  const centralOffset = tail.readUInt32LE(end + 16);
  if (count === 0xffff || centralOffset === 0xffffffff) {
    throw new Error("ZIP64 archives are not supported");
  }
  const central = Buffer.alloc(centralSize);
  fs.readSync(handle, central, 0, centralSize, centralOffset);
  const entries = [];
  let cursor = 0;
  for (let index = 0; index < count; index += 1) {
    if (central.readUInt32LE(cursor) !== 0x02014b50) {
      throw new Error("Corrupt ZIP central directory");
    }
    const nameLength = central.readUInt16LE(cursor + 28);
    const extraLength = central.readUInt16LE(cursor + 30);
    const commentLength = central.readUInt16LE(cursor + 32);
    entries.push({
      name: central.toString("utf8", cursor + 46, cursor + 46 + nameLength),
      method: central.readUInt16LE(cursor + 10),
      compressedSize: central.readUInt32LE(cursor + 20),
      size: central.readUInt32LE(cursor + 24),
      mode: central.readUInt32LE(cursor + 38) >>> 16,
      localOffset: central.readUInt32LE(cursor + 42),
    });
    cursor += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}

function readZipEntry(handle, entry) {
  const local = Buffer.alloc(30);
  fs.readSync(handle, local, 0, 30, entry.localOffset);
  if (local.readUInt32LE(0) !== 0x04034b50) {
    throw new Error(`Corrupt ZIP local header: ${entry.name}`);
  }
  const dataOffset = entry.localOffset + 30 + local.readUInt16LE(26) + local.readUInt16LE(28);
  const compressed = Buffer.alloc(entry.compressedSize);
  if (entry.compressedSize > 0) {
    fs.readSync(handle, compressed, 0, entry.compressedSize, dataOffset);
  }
  if (entry.method === 0) {
    return compressed;
  }
  if (entry.method === 8) {
    return zlib.inflateRawSync(compressed);
  }
  throw new Error(`Unsupported ZIP compression method ${entry.method}: ${entry.name}`);
}

// Opens a ZIP for reading. Call close() when done.
function openZip(zipPath) {
  const handle = fs.openSync(zipPath, "r");
  const entries = readZipDirectory(handle, fs.fstatSync(handle).size);
  return {
    entries,
    read: (entry) => readZipEntry(handle, entry),
    close: () => fs.closeSync(handle),
  };
}

function safeJoin(destination, name) {
  const target = path.resolve(destination, name);
  if (target !== destination && !target.startsWith(destination + path.sep)) {
    throw new Error(`Archive entry escapes the destination: ${name}`);
  }
  return target;
}

function extractZip(zipPath, destination) {
  const root = path.resolve(destination);
  const zip = openZip(zipPath);
  try {
    for (const entry of zip.entries) {
      const target = safeJoin(root, entry.name);
      if (entry.name.endsWith("/")) {
        fs.mkdirSync(target, { recursive: true });
        continue;
      }
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, zip.read(entry));
    }
  } finally {
    zip.close();
  }
}

function tarField(buffer, offset, length, value) {
  buffer.write(value, offset, length, "utf8");
}

function tarOctal(buffer, offset, length, value) {
  tarField(buffer, offset, length, value.toString(8).padStart(length - 1, "0") + "\0");
}

function splitTarName(name) {
  if (Buffer.byteLength(name) <= 100) {
    return { name, prefix: "" };
  }
  for (let index = name.indexOf("/"); index >= 0; index = name.indexOf("/", index + 1)) {
    const prefix = name.slice(0, index);
    const rest = name.slice(index + 1);
    if (Buffer.byteLength(prefix) <= 155 && Buffer.byteLength(rest) <= 100) {
      return { name: rest, prefix };
    }
  }
  throw new Error(`Path is too long for a ustar archive: ${name}`);
}

// entries: [{ name, data: Buffer, mode }] already in the order they should be stored.
function buildTar(entries, epoch) {
  const parts = [];
  for (const entry of entries) {
    const header = Buffer.alloc(TAR_BLOCK);
    const split = splitTarName(entry.name);
    tarField(header, 0, 100, split.name);
    tarOctal(header, 100, 8, entry.mode);
    tarOctal(header, 108, 8, 0);
    tarOctal(header, 116, 8, 0);
    tarOctal(header, 124, 12, entry.data.length);
    tarOctal(header, 136, 12, epoch);
    header.fill(0x20, 148, 156);
    header.write("0", 156, 1, "ascii");
    header.write("ustar\0", 257, 6, "binary");
    header.write("00", 263, 2, "ascii");
    tarField(header, 265, 32, "root");
    tarField(header, 297, 32, "root");
    tarField(header, 345, 155, split.prefix);
    let checksum = 0;
    for (const byte of header) {
      checksum += byte;
    }
    header.write(checksum.toString(8).padStart(6, "0") + "\0 ", 148, 8, "ascii");
    parts.push(header, entry.data);
    const padding = (TAR_BLOCK - (entry.data.length % TAR_BLOCK)) % TAR_BLOCK;
    if (padding > 0) {
      parts.push(Buffer.alloc(padding));
    }
  }
  parts.push(Buffer.alloc(TAR_BLOCK * 2));
  return Buffer.concat(parts);
}

// The gzip container is written by hand so the header carries a fixed mtime and
// OS byte; zlib.gzipSync would stamp the platform it runs on.
function gzipDeterministic(data, epoch) {
  const header = Buffer.from([0x1f, 0x8b, 0x08, 0x00, 0, 0, 0, 0, 0x02, 0xff]);
  header.writeUInt32LE(epoch >>> 0, 4);
  const trailer = Buffer.alloc(8);
  trailer.writeUInt32LE(zlib.crc32(data), 0);
  trailer.writeUInt32LE(data.length >>> 0, 4);
  return Buffer.concat([header, zlib.deflateRawSync(data, { level: 9 }), trailer]);
}

function tarString(buffer, offset, length) {
  const end = buffer.indexOf(0, offset);
  return buffer.toString("utf8", offset, end < 0 || end > offset + length ? offset + length : end);
}

// Returns [{ name, mode, data }] for the regular files of a .tar or .tar.gz buffer.
function readTar(buffer) {
  const tar = buffer[0] === 0x1f && buffer[1] === 0x8b ? zlib.gunzipSync(buffer) : buffer;
  const files = [];
  let offset = 0;
  let longName = "";
  while (offset + TAR_BLOCK <= tar.length) {
    const header = tar.subarray(offset, offset + TAR_BLOCK);
    if (header.every((byte) => byte === 0)) {
      break;
    }
    const size = parseInt(tarString(header, 124, 12).trim() || "0", 8);
    const type = String.fromCharCode(header[156] || 0x30);
    const dataStart = offset + TAR_BLOCK;
    const data = tar.subarray(dataStart, dataStart + size);
    if (type === "L") {
      longName = data.toString("utf8").replace(/\0+$/, "");
    } else {
      const prefix = tarString(header, 345, 155);
      const name = longName || (prefix ? `${prefix}/` : "") + tarString(header, 0, 100);
      longName = "";
      if (type === "0") {
        files.push({ name, mode: parseInt(tarString(header, 100, 8).trim() || "0", 8), data });
      }
    }
    offset = dataStart + Math.ceil(size / TAR_BLOCK) * TAR_BLOCK;
  }
  return files;
}

function extractTar(archivePath, destination) {
  const root = path.resolve(destination);
  for (const file of readTar(fs.readFileSync(archivePath))) {
    const target = safeJoin(root, file.name);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, file.data, { mode: file.mode });
  }
}

module.exports = {
  ZIP_MIN_EPOCH,
  buildZip,
  openZip,
  extractZip,
  buildTar,
  gzipDeterministic,
  readTar,
  extractTar,
};
