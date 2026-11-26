param([switch]$Web, [string]$Godot = "godot")
$ErrorActionPreference = "Stop"
Push-Location (Join-Path $PSScriptRoot "..")
try {
    New-Item -ItemType Directory -Force -Path "export/web" | Out-Null
    New-Item -ItemType File -Force -Path "export/.gdignore" | Out-Null
    function Invoke-Godot([string[]] $GodotArgs) {
        & $Godot @GodotArgs
        if ($LASTEXITCODE -ne 0) { throw "Godot exited $LASTEXITCODE" }
    }
    Invoke-Godot -GodotArgs @("--version")
    Invoke-Godot -GodotArgs @("--headless", "--path", ".", "--editor", "--import", "--quit")
    Invoke-Godot -GodotArgs @("--headless", "--path", ".", "--quit-after", "30")
    Invoke-Godot -GodotArgs @("--headless", "--path", ".", "--script", "res://tests/run_tests.gd")
    if ($Web) {
        New-Item -ItemType Directory -Force -Path "export/web" | Out-Null
        Invoke-Godot -GodotArgs @("--headless", "--path", ".", "--export-release", "Web", "export/web/index.html")
        foreach ($file in @("index.html", "index.js", "index.pck", "index.wasm")) {
            if (!(Test-Path "export/web/$file") -or (Get-Item "export/web/$file").Length -le 0) {
                throw "Missing or empty Web output: $file"
            }
        }
        Write-Host "Web export complete: export/web/index.html"
    }
} finally { Pop-Location }
