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

$outputExe = Join-Path $DistPath ("$ExeName.exe")
$altOutput = Join-Path $DistPath $ExeName

foreach ($existingOutput in @($outputExe, $altOutput)) {
    if (Test-Path -Path $existingOutput) {
        Remove-Item -Path $existingOutput -Force
    }
}

pyinstaller --noconfirm --clean --onefile --name "$ExeName" --distpath "$DistPath" "$EntryPoint"

if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller falló con código de salida $LASTEXITCODE"
}

if (-not (Test-Path -Path $outputExe)) {
    # En algunos entornos no-Windows pyinstaller puede generar binario sin extensión.
    if (Test-Path -Path $altOutput) {
        Move-Item -Path $altOutput -Destination $outputExe -Force
    }
}

if (-not (Test-Path -Path $outputExe)) {
    throw "No se pudo generar el EXE en $DistPath"
}

Write-Host "✅ EXE generado: $outputExe"
