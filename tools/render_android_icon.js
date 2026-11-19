#!/usr/bin/env node
// Draws each game's Android launcher icon from its project icon:
//
//   node tools/render_android_icon.js [--game <id>] [--godot-bin <godot>]
//
// Android draws an app's icon as two layers of 108 dp, of which a launcher
// shows the middle 72 dp, cut to its own shape (a circle, a rounded square),
// and the splash screen of Android 12 and later shows the foreground layer
// the same way. Given no layers, Godot makes the whole project icon the
// foreground, so a phone shows only its middle two thirds: the icon looks
// zoomed in, its edges cut off. This draws the project icon into the middle
// 72 dp of a 432-pixel foreground (a pixel-art icon stays crisp) and fills the
// background with the colour of the icon's edge, which shows where the shape
// of a launcher reaches past the icon's own rounded corners. It writes them to
// games/<id>/android_icon/, which Godot does not import (no pack carries
// them), with icon.json: the icon they were drawn from, so a check fails when
// the icon changes and they were not drawn again (tools/repository.test.js).
// The game's Android preset then names them (as tools/link.js keeps it).
// Without --game every game is drawn, and the new-game template too.
const fs = require("node:fs");
const path = require("node:path");
const { BACKGROUND, FOREGROUND, ICON_DIR, RECORD, expectedRecord, gameLabel, projectIcon } = require("./lib/android_icon");
const { fail, main, parseToolArgs, removeRecursive, resolveGodotBin, run, tempFile } = require("./lib/common");
const { gamePath, projectSetting, resolveGames, templateGame } = require("./lib/games");
const { syncProject } = require("./lib/project");

const PROBE_PROJECT = `[application]
config/name="Tiamat Android Icon Probe"

[rendering]
renderer/rendering_method="gl_compatibility"
`;

// Draws the two layers: the icon, as large as fits the middle 288 pixels (the
// 72 dp a launcher shows) of the 432 of the foreground; the background all of
// the colour of the icon's opaque edge, or white (as Android backs an icon of
// its own) when the edge is clear.
const PROBE_SCRIPT = `extends SceneTree

const CANVAS := 432
const ART := 288
const EDGE := 0.08

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("ANDROID_ICON: expected the icon, the output folder and the filter")
		quit(2)
		return
	var art := _art(args[0], args[2] == "nearest")
	if art == null:
		push_error("ANDROID_ICON: could not load %s" % args[0])
		quit(3)
		return
	var foreground := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	foreground.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i.ONE * ((CANVAS - ART) / 2))
	var background := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	background.fill(_edge_colour(art))
	if foreground.save_png(args[1].path_join("${FOREGROUND}")) != OK or background.save_png(args[1].path_join("${BACKGROUND}")) != OK:
		push_error("ANDROID_ICON: could not write to %s" % args[1])
		quit(4)
		return
	print("ANDROID_ICON_OK")
	quit(0)

# The icon in an ART square, as large as fits, in the middle.
func _art(source: String, nearest: bool) -> Image:
	var image := Image.new()
	if source.get_extension().to_lower() == "svg":
		var buffer := FileAccess.get_file_as_bytes(source)
		if image.load_svg_from_buffer(buffer) != OK:
			return null
		var scale := float(ART) / maxi(image.get_width(), image.get_height())
		if image.load_svg_from_buffer(buffer, scale) != OK:
			return null
	elif image.load(source) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	if nearest:
		# Pixel art grows by whole pixels first, so it shrinks to the size
		# with sharp edges.
		var factor := ceili(2.0 * ART / maxi(image.get_width(), image.get_height()))
		if factor > 1:
			image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	var scale := float(ART) / maxi(image.get_width(), image.get_height())
	var size := Vector2i(maxi(roundi(image.get_width() * scale), 1), maxi(roundi(image.get_height() * scale), 1))
	if size != image.get_size():
		image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var square := Image.create_empty(ART, ART, false, Image.FORMAT_RGBA8)
	square.blit_rect(image, Rect2i(Vector2i.ZERO, size), (Vector2i(ART, ART) - size) / 2)
	return square

# The mean colour of the opaque pixels near the edge of the art.
func _edge_colour(art: Image) -> Color:
	var band := int(ART * EDGE)
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for y: int in ART:
		for x: int in ART:
			if mini(mini(x, y), mini(ART - 1 - x, ART - 1 - y)) >= band:
				continue
			var pixel := art.get_pixel(x, y)
			if pixel.a < 0.95:
				continue
			sum += Color(pixel.r, pixel.g, pixel.b, 1.0)
			count += 1
	if count == 0:
		return Color.WHITE
	return Color(sum.r / count, sum.g / count, sum.b / count, 1.0)
`;

// Draws the layers of one game with Godot in an empty probe project.
async function renderAndroidIcon(game, godotBin) {
  const godot = resolveGodotBin(godotBin);
  const { file } = projectIcon(game);
  // 0 and 3 draw the game's textures with their pixels sharp.
  const filter = projectSetting(game, "rendering", "textures/canvas_textures/default_texture_filter");
  const nearest = filter === "0" || filter === "3";
  const out = gamePath(game, ICON_DIR);
  fs.mkdirSync(out, { recursive: true });
  const probeRoot = tempFile("tiamat-android-icon-probe");
  fs.mkdirSync(probeRoot, { recursive: true });
  fs.writeFileSync(path.join(probeRoot, "project.godot"), PROBE_PROJECT, "utf8");
  const probeScript = path.join(probeRoot, "probe.gd");
  fs.writeFileSync(probeScript, PROBE_SCRIPT, "utf8");
  try {
    const result = await run(godot, ["--headless", "--path", probeRoot, "-s", probeScript, "--", file, out, nearest ? "nearest" : "smooth"], { quiet: true });
    if (result.code !== 0 || !result.output.includes("ANDROID_ICON_OK")) {
      fail(`${gameLabel(game)}: drawing the launcher icon failed (exit code ${result.code}).\n${result.output.trim()}`);
    }
  } finally {
    removeRecursive(probeRoot);
  }
  fs.writeFileSync(path.join(out, ".gdignore"), "", "utf8");
  fs.writeFileSync(path.join(out, RECORD), `${JSON.stringify(expectedRecord(game), null, 2)}\n`, "utf8");
  if (!game.template) syncProject(game);
  console.log(`${gameLabel(game)}/${ICON_DIR}: launcher icon drawn from ${projectIcon(game).icon}.`);
}

module.exports = { renderAndroidIcon };

if (require.main === module) {
  main(async () => {
    const { values } = parseToolArgs({
      options: { game: { type: "string", multiple: true }, "godot-bin": { type: "string" } },
    });
    const games = resolveGames(values.game || []);
    if (!values.game) games.push(templateGame());
    for (const game of games) await renderAndroidIcon(game, values["godot-bin"]);
  });
}
