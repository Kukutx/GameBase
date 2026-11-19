"use strict";
// Converts Unity animation clips (.anim) into Godot Animation resources, and
// animator controllers and override controllers into AnimationLibrary
// resources, for tools/import_unity.js.
//
// A clip animates the objects below its Animator by path; the converted
// animation targets the same node names, relative to the node that held the
// Animator, so the AnimationPlayer goes under that node with root_node "..".
// Sprite keys become `texture` and `offset` keys of a Sprite2D whose
// `centered` is off (the offset puts the sprite's pivot on the node), flips
// become `flip_h`/`flip_v`, rotations and positions follow Godot's y-down
// axes in pixels, and animation events become method calls on the node.
const path = require("node:path");
const { GodotFile, raw, num, quote } = require("./godot_text");
const { floats } = require("./unity_assets");

const SPRITE_RENDERER = 212;
const GAME_OBJECT = 1;

function nodePathOf(unityPath, property) {
  return `${unityPath ? unityPath : "."}:${property}`;
}

// Offset of a Sprite2D (centered off) that puts the sprite's pivot on its node.
function spriteOffset(sprite, flipH = false, flipV = false) {
  const x = flipH ? -(sprite.region.width - sprite.pivot.x) : -sprite.pivot.x;
  const y = flipV ? -(sprite.region.height - sprite.pivot.y) : -sprite.pivot.y;
  return [x, y];
}

function valueTrack(file, trackPath, keys, update, interpolation = 1) {
  return {
    type: "value",
    path: trackPath,
    interp: interpolation,
    keys: raw(`{\n"times": ${floats(keys.map((key) => key.time)).text},\n"transitions": ${floats(keys.map(() => 1)).text},\n"update": ${update},\n"values": [${keys.map((key) => key.value).join(", ")}]\n}`),
  };
}

// The value of a stepped float curve at `time`.
function stepAt(curve, time) {
  let result = null;
  for (const key of curve) if (Number(key.time) <= time + 1e-6) result = Number(key.value);
  return result;
}

class AnimationConverter {
  constructor(project, assets) {
    this.project = project;
    this.assets = assets;
  }

  // Adds the clip in `clipFile` to `file` as an Animation sub-resource named
  // `animationName`; returns its reference.
  addClip(file, clipFile, animationName) {
    const documents = this.project.load(clipFile);
    const clip = [...documents.values()].find((document) => document.type === "AnimationClip");
    if (!clip) return null;
    const data = clip.data;
    const settings = data.m_AnimationClipSettings ?? {};
    const tracks = [];
    let length = Number(settings.m_StopTime ?? 0);
    const ppu = this.assets.pixelsPerUnit;
    const floatCurves = data.m_FloatCurves ?? [];
    const flipCurve = (unityPath, attribute) => floatCurves.find((curve) => String(curve.path ?? "") === String(unityPath ?? "") && curve.attribute === attribute && Number(curve.classID) === SPRITE_RENDERER);

    for (const curve of data.m_PPtrCurves ?? []) {
      if (curve.attribute !== "m_Sprite") continue;
      const unityPath = String(curve.path ?? "");
      const flipH = flipCurve(unityPath, "m_FlipX")?.curve?.m_Curve ?? [];
      const flipV = flipCurve(unityPath, "m_FlipY")?.curve?.m_Curve ?? [];
      const textureKeys = [];
      const offsetKeys = [];
      for (const key of curve.curve ?? []) {
        const time = Number(key.time);
        length = Math.max(length, time);
        const sprite = this.project.sprite(key.value);
        if (!sprite) {
          textureKeys.push({ time, value: "null" });
          continue;
        }
        textureKeys.push({ time, value: file.extResource("Texture2D", this.assets.atlas(sprite)).text });
        const [x, y] = spriteOffset(sprite, stepAt(flipH, time) === 1, stepAt(flipV, time) === 1);
        offsetKeys.push({ time, value: `Vector2(${num(x)}, ${num(y)})` });
      }
      tracks.push(valueTrack(file, nodePathOf(unityPath, "texture"), textureKeys, 1));
      if (offsetKeys.length) tracks.push(valueTrack(file, nodePathOf(unityPath, "offset"), offsetKeys, 1));
    }

    for (const curve of floatCurves) {
      const unityPath = String(curve.path ?? "");
      const keys = (curve.curve?.m_Curve ?? []).map((key) => ({ time: Number(key.time), number: Number(key.value) }));
      keys.forEach((key) => { length = Math.max(length, key.time); });
      const classId = Number(curve.classID);
      let property = null;
      let convert = (number) => num(number);
      let update = 0;
      if (classId === SPRITE_RENDERER && curve.attribute === "m_FlipX") [property, convert, update] = ["flip_h", (n) => (n === 1 ? "true" : "false"), 1];
      else if (classId === SPRITE_RENDERER && curve.attribute === "m_FlipY") [property, convert, update] = ["flip_v", (n) => (n === 1 ? "true" : "false"), 1];
      else if (classId === SPRITE_RENDERER && curve.attribute === "m_Enabled") [property, convert, update] = ["visible", (n) => (n === 1 ? "true" : "false"), 1];
      else if (classId === GAME_OBJECT && curve.attribute === "m_IsActive") [property, convert, update] = ["visible", (n) => (n === 1 ? "true" : "false"), 1];
      else if (classId === SPRITE_RENDERER && curve.attribute === "m_SortingOrder") [property, convert, update] = ["z_index", (n) => String(Math.round(n)), 1];
      else if (curve.attribute === "m_Color.a") property = "modulate:a";
      else if (curve.attribute === "m_Color.r") property = "modulate:r";
      else if (curve.attribute === "m_Color.g") property = "modulate:g";
      else if (curve.attribute === "m_Color.b") property = "modulate:b";
      else if (curve.attribute === "m_LocalPosition.x") convert = (n) => num(n * ppu), property = "position:x";
      else if (curve.attribute === "m_LocalPosition.y") convert = (n) => num(-n * ppu), property = "position:y";
      else if (curve.attribute === "localEulerAnglesRaw.z") convert = (n) => num((-n * Math.PI) / 180), property = "rotation";
      else if (curve.attribute === "m_LocalScale.x") property = "scale:x";
      else if (curve.attribute === "m_LocalScale.y") property = "scale:y";
      if (!property) {
        this.assets.warn(`clip ${data.m_Name}: curve ${curve.attribute} of class ${classId} is not converted`);
        continue;
      }
      const target = unityPath ? `${unityPath}:${property}` : `.:${property}`;
      tracks.push(valueTrack(file, target, keys.map((key) => ({ time: key.time, value: convert(key.number) })), update));
    }

    for (const curve of data.m_EulerCurves ?? []) {
      const keys = (curve.curve?.m_Curve ?? []).map((key) => {
        length = Math.max(length, Number(key.time));
        return { time: Number(key.time), value: num((-Number(key.value?.z ?? 0) * Math.PI) / 180) };
      });
      tracks.push(valueTrack(file, nodePathOf(String(curve.path ?? ""), "rotation"), keys, 0));
    }
    for (const curve of data.m_PositionCurves ?? []) {
      const keys = (curve.curve?.m_Curve ?? []).map((key) => {
        length = Math.max(length, Number(key.time));
        return { time: Number(key.time), value: `Vector2(${num(Number(key.value?.x ?? 0) * ppu)}, ${num(-Number(key.value?.y ?? 0) * ppu)})` };
      });
      tracks.push(valueTrack(file, nodePathOf(String(curve.path ?? ""), "position"), keys, 0));
    }
    for (const curve of data.m_ScaleCurves ?? []) {
      const keys = (curve.curve?.m_Curve ?? []).map((key) => {
        length = Math.max(length, Number(key.time));
        return { time: Number(key.time), value: `Vector2(${num(key.value?.x ?? 1)}, ${num(key.value?.y ?? 1)})` };
      });
      tracks.push(valueTrack(file, nodePathOf(String(curve.path ?? ""), "scale"), keys, 0));
    }
    const events = (data.m_Events ?? []).filter((event) => event.functionName);
    if (events.length) {
      tracks.push({
        type: "method",
        path: ".",
        keys: raw(`{\n"times": ${floats(events.map((event) => Number(event.time))).text},\n"transitions": ${floats(events.map(() => 1)).text},\n"values": [${events.map((event) => `{\n"args": [],\n"method": &${quote(event.functionName)}\n}`).join(", ")}]\n}`),
      });
    }

    const sampleRate = Number(data.m_SampleRate ?? 60) || 60;
    const properties = [
      ["resource_name", animationName],
      ["length", Math.max(length, 1 / sampleRate)],
      ["loop_mode", Number(settings.m_LoopTime ?? 0) === 1 ? 1 : 0],
      ["step", 1 / sampleRate],
    ];
    tracks.forEach((track, index) => {
      const prefix = `tracks/${index}`;
      properties.push([`${prefix}/type`, track.type]);
      properties.push([`${prefix}/imported`, false]);
      properties.push([`${prefix}/enabled`, true]);
      properties.push([`${prefix}/path`, raw(`NodePath(${quote(track.path)})`)]);
      if (track.type === "value") {
        properties.push([`${prefix}/interp`, track.interp]);
        properties.push([`${prefix}/loop_wrap`, true]);
      } else {
        properties.push([`${prefix}/interp`, 1]);
        properties.push([`${prefix}/loop_wrap`, true]);
      }
      properties.push([`${prefix}/keys`, track.keys]);
    });
    return file.subResource("Animation", properties, "Animation");
  }

  // Clip files of a controller (by state and blend tree), as name -> file.
  controllerClips(controllerFile) {
    const clips = new Map();
    const visit = (reference) => {
      if (!reference) return;
      const target = this.project.fileOf(reference, controllerFile);
      if (!target) return;
      if (target !== controllerFile && target.endsWith(".anim")) {
        clips.set(path.basename(target, ".anim"), target);
        return;
      }
      const document = this.project.load(target).get(String(reference.fileID));
      if (document?.type === "BlendTree") for (const child of document.data.m_Childs ?? []) visit(child.m_Motion);
    };
    for (const document of this.project.load(controllerFile).values()) {
      if (document.type === "AnimatorState") visit(document.data.m_Motion);
    }
    return clips;
  }

  // The clip name of the default state of a controller's first layer, or null.
  defaultClip(controllerFile) {
    const documents = this.project.load(controllerFile);
    const controller = [...documents.values()].find((document) => document.type === "AnimatorController");
    const machineId = controller?.data?.m_AnimatorLayers?.[0]?.m_StateMachine?.fileID;
    const machine = machineId !== undefined ? documents.get(String(machineId)) : null;
    const state = machine ? documents.get(String(machine.data.m_DefaultState?.fileID)) : null;
    const motion = state?.data?.m_Motion;
    const target = motion ? this.project.fileOf(motion, controllerFile) : null;
    return target && target.endsWith(".anim") ? path.basename(target, ".anim") : null;
  }

  // An AnimationLibrary of a controller (.controller) or override controller
  // (.overrideController): the base controller's clips by their names, each
  // replaced by its override.
  library(controllerFile) {
    let clips;
    if (controllerFile.endsWith(".overrideController")) {
      const override = [...this.project.load(controllerFile).values()].find((document) => document.type === "AnimatorOverrideController");
      const base = this.project.fileOf(override.data.m_Controller, controllerFile);
      clips = base ? this.controllerClips(base) : new Map();
      for (const pair of override.data.m_Clips ?? []) {
        const original = this.project.fileOf(pair.m_OriginalClip, controllerFile);
        const replacement = this.project.fileOf(pair.m_OverrideClip, controllerFile);
        if (original && replacement && replacement.endsWith(".anim")) clips.set(path.basename(original, ".anim"), replacement);
      }
    } else {
      clips = this.controllerClips(controllerFile);
    }
    return this.clipsLibrary(clips);
  }

  // An AnimationLibrary of clips given as name -> .anim file.
  clipsLibrary(clips) {
    const file = new GodotFile("gd_resource", { type: "AnimationLibrary" });
    const entries = [];
    for (const [clipName, clipFile] of [...clips.entries()].sort()) {
      const reference = this.addClip(file, clipFile, clipName);
      if (reference) entries.push(`&${quote(clipName)}: ${reference.text}`);
    }
    file.section("[resource]", [["_data", raw(`{\n${entries.join(",\n")}\n}`)]]);
    return file.toString();
  }
}

module.exports = { AnimationConverter, spriteOffset };
