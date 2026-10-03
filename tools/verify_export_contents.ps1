[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PckPath,
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $GodotBin = "godot"
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ResolvedPck = if ([System.IO.Path]::IsPathRooted($PckPath)) {
    (Resolve-Path $PckPath).Path
} else {
    (Resolve-Path (Join-Path $Root $PckPath)).Path
}

$GodotCommand = $GodotBin
if (Test-Path $GodotBin) {
    $GodotCommand = (Resolve-Path $GodotBin).Path
}

$ProbeRoot = Join-Path (Join-Path $Root ".dev") "export-pack-probe"
New-Item -ItemType Directory -Force -Path $ProbeRoot | Out-Null

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectText = @"
[application]
config/name="GameBase Export Pack Probe"

[rendering]
renderer/rendering_method="gl_compatibility"
"@
[System.IO.File]::WriteAllText((Join-Path $ProbeRoot "project.godot"), $ProjectText, $Utf8NoBom)

$ProbeScript = @'
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("EXPORT_CONTENTS: missing PCK path")
		quit(2)
		return

	var pack_path := args[0]
	if not ProjectSettings.load_resource_pack(pack_path, true):
		push_error("EXPORT_CONTENTS: could not load PCK: %s" % pack_path)
		quit(3)
		return

	var required := [
		"res://game/ui/title_screen.tscn",
		"res://game/i18n/ui.zh_CN.po",
		"res://addons/dialogue_manager/dialogue_manager.gd",
	]
	for path: String in required:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			push_error("EXPORT_CONTENTS: required runtime resource missing: %s" % path)
			quit(4)
			return

	var forbidden_files := [
		"res://.gutconfig.json",
		"res://AGENTS.md",
		"res://README.md",
		"res://LICENSE",
		"res://THIRD_PARTY_NOTICES.md",
	]
	for path: String in forbidden_files:
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			push_error("EXPORT_CONTENTS: forbidden development file packaged: %s" % path)
			quit(5)
			return

	var forbidden_dirs := [
		"res://test",
		"res://addons/gut",
		"res://game/art/licensed",
		"res://tools",
		"res://docs",
		"res://.github",
		"res://.devmate",
		"res://build",
		"res://artifacts",
		"res://licenses",
	]
	for path: String in forbidden_dirs:
		if DirAccess.dir_exists_absolute(path):
			push_error("EXPORT_CONTENTS: forbidden development directory packaged: %s" % path)
			quit(6)
			return

	print("EXPORT_CONTENTS_OK")
	quit(0)
'@

$ProbeScriptPath = Join-Path $ProbeRoot "probe.gd"
[System.IO.File]::WriteAllText($ProbeScriptPath, $ProbeScript, $Utf8NoBom)

$LogPath = Join-Path ([System.IO.Path]::GetTempPath()) "gamebase-export-pack-probe.log"
Remove-Item $LogPath -Force -ErrorAction SilentlyContinue

& $GodotCommand --headless --path $ProbeRoot -s $ProbeScriptPath -- $ResolvedPck 2>&1 | Tee-Object -FilePath $LogPath
$ExitCode = $LASTEXITCODE
$Output = Get-Content $LogPath -Raw
Remove-Item $LogPath -Force -ErrorAction SilentlyContinue

if ($ExitCode -ne 0) {
    throw "Export content verification failed for '$PckPath' with exit code $ExitCode."
}
if ($Output -notmatch "EXPORT_CONTENTS_OK") {
    throw "Export content verification did not report success for '$PckPath'."
}

Write-Host "Export content verification passed: $PckPath"
