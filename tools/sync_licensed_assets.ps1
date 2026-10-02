param(
    [string]$GandalfRoot = 'A:\Project\Godot\Asset\GandalfHardcore',
    [string]$CraftpixArchive = 'A:\Project\Godot\Asset\参考\craftpix-net-436971-free-top-down-roguelike-game-kit-pixel-art.zip'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$DestinationRoot = Join-Path $ProjectRoot 'game\art\licensed'
$TempRoot = Join-Path $env:TEMP ('gamebase-licensed-assets-' + [Guid]::NewGuid().ToString('N'))

$gandalfPacks = @(
    @{ Zip = 'GandalfHardcore Pixel Art Village Houses tiles.zip'; Folder = 'GandalfHardcore Pixel Art Village Houses tiles'; Destination = 'gandalf_village' },
    @{ Zip = 'GandalfHardcore Farming Tiles and Crops 32x32.zip'; Folder = 'GandalfHardcore Farming Tiles and Crops 32x32'; Destination = 'gandalf_farming' },
    @{ Zip = 'GandalfHardcore House Asset Pack 32x32.zip'; Folder = 'GandalfHardcore House Asset Pack 32x32'; Destination = 'gandalf_house' },
    @{ Zip = 'GandalfHardcore Farm Animals.zip'; Folder = 'GandalfHardcore Farm Animals'; Destination = 'gandalf_animals' },
    @{ Zip = 'GandalfHardcore Slime Enemy.zip'; Folder = 'GandalfHardcore Slime Enemy'; Destination = 'gandalf_slime' }
)

New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
    foreach ($pack in $gandalfPacks) {
        $zipPath = Join-Path $GandalfRoot $pack.Zip
        if (-not (Test-Path $zipPath)) {
            throw "Missing licensed source archive: $zipPath"
        }
        $extractRoot = Join-Path $TempRoot $pack.Destination
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
        $sourceFolder = Join-Path $extractRoot $pack.Folder
        $destination = Join-Path $DestinationRoot $pack.Destination
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        Get-ChildItem -LiteralPath $sourceFolder -Filter '*.png' -File | Copy-Item -Destination $destination -Force
    }

    if (-not (Test-Path $CraftpixArchive)) {
        throw "Missing Craftpix source archive: $CraftpixArchive"
    }
    $craftpixExtract = Join-Path $TempRoot 'craftpix_roguelike'
    Expand-Archive -LiteralPath $CraftpixArchive -DestinationPath $craftpixExtract -Force
    foreach ($characterId in 1, 2, 3) {
        $source = Join-Path $craftpixExtract "1 Characters\$characterId"
        $destination = Join-Path $DestinationRoot "craftpix_roguelike\character$characterId"
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        foreach ($name in 'D_Idle.png','D_Walk.png','U_Idle.png','U_Walk.png','S_Idle.png','S_Walk.png','D_Attack.png','U_Attack.png','S_Attack.png','D_Hurt.png','U_Hurt.png','S_Hurt.png','D_Death.png','U_Death.png','S_Death.png') {
            $file = Join-Path $source $name
            if (-not (Test-Path $file)) {
                throw "Missing Craftpix character strip: $file"
            }
            Copy-Item -LiteralPath $file -Destination $destination -Force
        }
    }

    Write-Host "Licensed art synchronized to $DestinationRoot"
}
finally {
    if (Test-Path $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}
