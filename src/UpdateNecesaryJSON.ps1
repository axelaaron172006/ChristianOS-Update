[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ManifestPath = "./manifests/KB0001-ChristianOS11-25H2.json",

    [Parameter(Mandatory = $false)]
    [switch]$UpdateManifest
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $ManifestPath)) {
    throw "No se encontró el manifiesto: $ManifestPath"
}

$manifestRaw = Get-Content -Path $ManifestPath -Raw
$manifest = $manifestRaw | ConvertFrom-Json

if (-not $manifest.reporting.logFile) {
    throw "El manifiesto no contiene reporting.logFile"
}

$logPath = $manifest.reporting.logFile
$logDir = Split-Path -Path $logPath -Parent
if ($logDir -and -not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

"ChristianOS Update Report - $($manifest.updateName)" | Out-File -FilePath $logPath -Encoding UTF8
"Manifest: $ManifestPath" | Out-File -FilePath $logPath -Append -Encoding UTF8
"Fecha: $(Get-Date -Format \"yyyy-MM-dd HH:mm:ss\")" | Out-File -FilePath $logPath -Append -Encoding UTF8


$allowedTypes = @("CAB", "MSI", "MSU")
if ($manifest.type -and ($allowedTypes -notcontains $manifest.type.ToUpper())) {
    "[WARN] Tipo de paquete no reconocido en manifiesto: $($manifest.type)" | Out-File -FilePath $logPath -Append -Encoding UTF8
}

$hasMissingFiles = $false
$combinedHashInput = New-Object System.Collections.Generic.List[string]

for ($i = 0; $i -lt $manifest.files.Count; $i++) {
    $file = $manifest.files[$i]
    $filePath = $file.path

    if (-not (Test-Path -Path $filePath)) {
        "[$(Get-Date)] ❌ Falta archivo: $($file.name) ($filePath)" | Out-File -FilePath $logPath -Append -Encoding UTF8
        $hasMissingFiles = $true
        continue
    }

    $fileInfo = Get-Item -Path $filePath
    $sha = Get-FileHash -Path $filePath -Algorithm SHA256

    $manifest.files[$i].size = $fileInfo.Length
    $manifest.files[$i].sha256 = $sha.Hash

    $combinedHashInput.Add($sha.Hash)

    "[$(Get-Date)] ✅ $($file.name)" | Out-File -FilePath $logPath -Append -Encoding UTF8
    "    Ruta: $filePath" | Out-File -FilePath $logPath -Append -Encoding UTF8
    "    Tamaño: $($fileInfo.Length) bytes" | Out-File -FilePath $logPath -Append -Encoding UTF8
    "    SHA256: $($sha.Hash)" | Out-File -FilePath $logPath -Append -Encoding UTF8
}

if ($combinedHashInput.Count -gt 0) {
    $joinedHashes = ($combinedHashInput -join "")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joinedHashes)
    $stream = [System.IO.MemoryStream]::new($bytes)
    try {
        $overallHash = Get-FileHash -InputStream $stream -Algorithm SHA256
        $manifest.sha256 = $overallHash.Hash
    }
    finally {
        $stream.Dispose()
    }
}

if ($hasMissingFiles) {
    $manifest.reporting.status = "FAILED"
    "Estado: ❌ FAILED (faltan archivos)" | Out-File -FilePath $logPath -Append -Encoding UTF8
}
else {
    $manifest.reporting.status = "VALIDATED"
    "Estado: ✅ VALIDATED" | Out-File -FilePath $logPath -Append -Encoding UTF8
}

if ($UpdateManifest) {
    $manifest | ConvertTo-Json -Depth 8 | Out-File -FilePath $ManifestPath -Encoding UTF8
    "Manifest actualizado: ✅ $ManifestPath" | Out-File -FilePath $logPath -Append -Encoding UTF8
}

Write-Host "Validación terminada. Log: $logPath"
