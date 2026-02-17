[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $false)]
    [string]$Notes = "Release automática de ChristianOS Update",

    [Parameter(Mandatory = $false)]
    [string]$AssetPath = "./src/UpdateNecesaryJSON.ps1",

    [Parameter(Mandatory = $false)]
    [switch]$Draft,

    [Parameter(Mandatory = $false)]
    [switch]$Prerelease
)

$ErrorActionPreference = "Stop"

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    throw "No se encontró GitHub CLI (gh). Instálalo desde https://cli.github.com/"
}

if (-not (Test-Path -Path $AssetPath)) {
    throw "No existe el archivo a adjuntar: $AssetPath"
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw "No se detectó un repositorio git válido"
}

$releaseArgs = @("release", "create", $Tag, $AssetPath, "--title", $Title, "--notes", $Notes)

if ($Draft) {
    $releaseArgs += "--draft"
}

if ($Prerelease) {
    $releaseArgs += "--prerelease"
}

Write-Host "Creando release en GitHub..."
& gh @releaseArgs

Write-Host "✅ Release creada: $Tag"
Write-Host "✅ Asset adjunto: $AssetPath"
