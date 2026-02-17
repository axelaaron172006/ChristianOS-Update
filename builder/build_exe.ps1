[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$EntryPoint = "./src/generate_kb_with_ai.py",

    [Parameter(Mandatory = $false)]
    [string]$ExeName = "ChristianOSUpdateAI",

    [Parameter(Mandatory = $false)]
    [string]$DistPath = "./builder/exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $EntryPoint)) {
    throw "No existe el entrypoint: $EntryPoint"
}

$pyinstaller = Get-Command pyinstaller -ErrorAction SilentlyContinue
if (-not $pyinstaller) {
    throw "No se encontró 'pyinstaller'. Instálalo con: pip install pyinstaller"
}

New-Item -ItemType Directory -Path $DistPath -Force | Out-Null

pyinstaller --noconfirm --clean --onefile --name "$ExeName" --distpath "$DistPath" "$EntryPoint"

$outputExe = Join-Path $DistPath ("$ExeName.exe")
if (-not (Test-Path -Path $outputExe)) {
    # En algunos entornos no-Windows pyinstaller puede generar binario sin extensión.
    $altOutput = Join-Path $DistPath $ExeName
    if (Test-Path -Path $altOutput) {
        Move-Item -Path $altOutput -Destination $outputExe -Force
    }
}

if (-not (Test-Path -Path $outputExe)) {
    throw "No se pudo generar el EXE en $DistPath"
}

Write-Host "✅ EXE generado: $outputExe"
