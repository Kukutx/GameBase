[CmdletBinding()]
param(
    [ValidateSet("Windows", "Web")]
    [string[]]$Target = @("Windows", "Web")
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Artifacts = Join-Path $Root "artifacts\release-smoke"
New-Item -ItemType Directory -Force -Path $Artifacts | Out-Null

function Assert-CleanLog {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if (-not (Test-Path $Path)) {
        return
    }
    $Failures = @(Select-String -Path $Path -Pattern '^(?:ERROR|SCRIPT ERROR):' -CaseSensitive:$false)
    if ($Failures.Count -gt 0) {
        $Failures | ForEach-Object { Write-Error $_.Line }
        throw "$Name emitted $($Failures.Count) runtime error line(s)."
    }
}

Push-Location $Root
try {
    foreach ($Name in $Target) {
        switch ($Name) {
            "Windows" {
                $Exe = Join-Path $Root "build\windows\GameBase.exe"
                if (-not (Test-Path $Exe)) {
                    throw "Windows export not found: $Exe"
                }
                $Stdout = Join-Path $Artifacts "windows.stdout.log"
                $Stderr = Join-Path $Artifacts "windows.stderr.log"
                Remove-Item $Stdout, $Stderr -Force -ErrorAction SilentlyContinue

                Write-Host "==> Windows exported-build smoke"
                $Process = Start-Process -FilePath $Exe `
                    -ArgumentList @("--headless", "--quit-after", "120") `
                    -RedirectStandardOutput $Stdout `
                    -RedirectStandardError $Stderr `
                    -Wait -PassThru
                if ($Process.ExitCode -ne 0) {
                    Get-Content $Stdout, $Stderr -ErrorAction SilentlyContinue
                    throw "Windows exported build exited with code $($Process.ExitCode)."
                }
                Assert-CleanLog -Path $Stdout -Name "Windows exported build"
                Assert-CleanLog -Path $Stderr -Name "Windows exported build"
                Write-Host "Windows exported-build smoke passed."
            }
            "Web" {
                $WebRoot = Join-Path $Root "build\web"
                $Index = Join-Path $WebRoot "index.html"
                if (-not (Test-Path $Index)) {
                    throw "Web export not found: $Index"
                }
                foreach ($Extension in @("*.js", "*.wasm", "*.pck")) {
                    if (@(Get-ChildItem -Path $WebRoot -Filter $Extension -File).Count -lt 1) {
                        throw "Web export is missing required payload: $Extension"
                    }
                }
                Write-Host "Web export payload smoke passed."
            }
        }
    }
}
finally {
    Pop-Location
}
