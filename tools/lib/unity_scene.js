"use strict";
// Resolves the object graph of a Unity scene or prefab into a tree of game
// objects, with prefab instances (and variants) expanded and their
// modifications applied: [{ id, name, active, transform, components, children }].
// Each component is { classId, type, script, data }; `script` is the
// MonoBehaviour's class name.

const TRANSFORM_CLASSES = new Set([4, 224]);
const GAME_OBJECT = 1;
const PREFAB_INSTANCE = 1001;

// The file id Unity gives, in the file holding a prefab instance, to an object
// of that instance that the file does not list itself.
function nestedFileId(instanceId, sourceId) {
  try {
    const mixed = BigInt.asUintN(64, BigInt(instanceId)) ^ BigInt.asUintN(64, BigInt(sourceId));
    return String(mixed & 0x7fffffffffffffffn);
  } catch {
    return null;
  }
}

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

// Sets `propertyPath` (m_LocalPosition.x, m_Points.m_Paths.Array.data[0].Array.data[2].x)
// on `data` to `value`, creating containers as needed.
function setProperty(data, propertyPath, value) {
  const parts = propertyPath.replace(/\.Array\.data\[(\d+)\]/g, ".[$1]").replace(/\.Array\.size$/, ".[size]").split(".");
  let target = data;
  for (let index = 0; index < parts.length; index += 1) {
    const part = parts[index];
    const last = index === parts.length - 1;
    const arrayIndex = /^\[(\d+)\]$/.exec(part);
    if (part === "[size]") {
      if (Array.isArray(target)) target.length = Number(value);
      return;
    }
    const key = arrayIndex ? Number(arrayIndex[1]) : part;
    if (last) {
      target[key] = value;
      return;
    }
    if (target[key] === null || typeof target[key] !== "object") target[key] = /^\[\d+\]$/.test(parts[index + 1]) || parts[index + 1] === "[size]" ? [] : {};
    target = target[key];
  }
}

class SceneResolver {
  constructor(project) {
    this.project = project;
    this.cache = new Map();
  }

  // { records: Map<id, document>, idMap: Map<local file id, record id> } of a file.
  resolveFile(file) {
    if (this.cache.has(file)) return this.cache.get(file);
    const documents = this.project.load(file);
    const records = new Map();
    const idMap = new Map();
    const instances = [];
    for (const [fileId, document] of documents) {
      if (document.classId === PREFAB_INSTANCE) instances.push(document);
      else if (!document.stripped) {
        records.set(fileId, { classId: document.classId, type: document.type, data: clone(document.data) });
        idMap.set(fileId, fileId);
      }
    }
    for (const instance of instances) {
      this.expandInstance(file, instance, records, idMap);
      // Objects of the instance keep an id of their own in this file, which
      // outer files refer to.
      for (const [sourceId, recordId] of this.instanceMaps?.get(`${file}|${instance.fileId}`) ?? []) {
        const id = nestedFileId(instance.fileId, sourceId);
        if (id && !idMap.has(id)) idMap.set(id, recordId);
      }
    }
    // Stripped documents name an object of an instance: map them to it.
    for (const [fileId, document] of documents) {
      if (!document.stripped) continue;
      const instanceId = String(document.data.m_PrefabInstance?.fileID ?? "");
      const sourceId = String(document.data.m_CorrespondingSourceObject?.fileID ?? "");
      const nested = this.instanceMaps?.get(`${file}|${instanceId}`);
      if (nested && nested.has(sourceId)) idMap.set(fileId, nested.get(sourceId));
    }
    // Structural references inside this file now point at record ids.
    const remap = (reference) => {
      if (!reference || reference.guid || reference.fileID === undefined) return reference;
      const mapped = idMap.get(String(reference.fileID));
      return mapped === undefined ? reference : { fileID: mapped };
    };
    for (const record of records.values()) {
      const data = record.data;
      if (record.classId === GAME_OBJECT && Array.isArray(data.m_Component)) {
        data.m_Component = data.m_Component.map((entry) => ({ component: remap(entry.component) }));
      }
      if (TRANSFORM_CLASSES.has(record.classId)) {
        data.m_Father = remap(data.m_Father);
        data.m_Children = (data.m_Children ?? []).map(remap);
      }
      if (data.m_GameObject) data.m_GameObject = remap(data.m_GameObject);
    }
    const result = { records, idMap };
    this.cache.set(file, result);
    return result;
  }

  expandInstance(file, instance, records, idMap) {
    const source = this.project.fileOf(instance.data.m_SourcePrefab, file);
    if (!source) return;
    const base = this.resolveFile(source);
    const prefix = `${instance.fileId}/`;
    const nestedMap = new Map();
    for (const [localId, recordId] of base.idMap) nestedMap.set(localId, prefix + recordId);
    this.instanceMaps ??= new Map();
    this.instanceMaps.set(`${file}|${instance.fileId}`, nestedMap);
    const copies = new Map();
    for (const [recordId, record] of base.records) {
      const copy = { classId: record.classId, type: record.type, data: clone(record.data) };
      const data = copy.data;
      const local = (reference) => (reference && !reference.guid && reference.fileID !== undefined && base.records.has(String(reference.fileID))
        ? { fileID: prefix + reference.fileID } : reference);
      if (copy.classId === GAME_OBJECT && Array.isArray(data.m_Component)) data.m_Component = data.m_Component.map((entry) => ({ component: local(entry.component) }));
      if (TRANSFORM_CLASSES.has(copy.classId)) {
        data.m_Father = local(data.m_Father);
        data.m_Children = (data.m_Children ?? []).map(local);
      }
      if (data.m_GameObject) data.m_GameObject = local(data.m_GameObject);
      copies.set(prefix + recordId, copy);
    }
    const modification = instance.data.m_Modification ?? {};
    for (const change of modification.m_Modifications ?? []) {
      const target = nestedMap.get(String(change.target?.fileID));
      const record = target && copies.get(target);
      if (!record) continue;
      const reference = change.objectReference;
      const hasReference = reference && (reference.guid || (reference.fileID && String(reference.fileID) !== "0"));
      setProperty(record.data, String(change.propertyPath), hasReference ? clone(reference) : change.value);
    }
    for (const removed of modification.m_RemovedComponents ?? []) {
      const target = nestedMap.get(String(removed?.fileID));
      if (target) copies.delete(target);
    }
    // The instance's root transform hangs under the scene object it was placed in.
    const parentId = String(modification.m_TransformParent?.fileID ?? "0");
    for (const copy of copies.values()) {
      if (TRANSFORM_CLASSES.has(copy.classId) && (!copy.data.m_Father || String(copy.data.m_Father.fileID) === "0")) {
        copy.data.m_Father = { fileID: parentId };
        copy.instanceRoot = true;
      }
    }
    for (const [id, copy] of copies) records.set(id, copy);
  }

  // The tree of game objects of `file`.
  tree(file) {
    const { records } = this.resolveFile(file);
    const transformOf = new Map();
    for (const [id, record] of records) {
      if (TRANSFORM_CLASSES.has(record.classId)) {
        const owner = String(record.data.m_GameObject?.fileID ?? "");
        transformOf.set(owner, id);
      }
    }
    const nodes = new Map();
    for (const [id, record] of records) {
      if (record.classId !== GAME_OBJECT) continue;
      const transformId = transformOf.get(id);
      const transform = transformId ? records.get(transformId) : null;
      const components = [];
      for (const entry of record.data.m_Component ?? []) {
        const component = records.get(String(entry.component?.fileID));
        if (!component || TRANSFORM_CLASSES.has(component.classId)) continue;
        components.push({
          classId: component.classId,
          type: component.type,
          script: component.classId === 114 ? this.project.scriptName({ data: component.data }) : null,
          data: component.data,
        });
      }
      nodes.set(transformId ?? id, {
        id,
        name: String(record.data.m_Name ?? "GameObject"),
        active: Number(record.data.m_IsActive ?? 1) !== 0,
        transform: transform ? { classId: transform.classId, ...transform.data } : null,
        transformId,
        components,
        children: [],
      });
    }
    const roots = [];
    for (const node of nodes.values()) {
      const father = String(node.transform?.m_Father?.fileID ?? "0");
      const parent = father !== "0" ? nodes.get(father) : null;
      (parent ? parent.children : roots).push(node);
    }
    const order = (node) => Number(node.transform?.m_RootOrder ?? 0);
    const sort = (list) => {
      list.sort((a, b) => order(a) - order(b));
      for (const node of list) sort(node.children);
    };
    sort(roots);
    return roots;
  }
}

module.exports = { SceneResolver, setProperty };
