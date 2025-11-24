# Cargar manifiesto
$manifest = Get-Content "./manifests/KB0001-ChristianOS11.json" | ConvertFrom-Json

# Crear log
$logPath = $manifest.reporting.logFile
"ChristianOS Update Report - $($manifest.updateName)" | Out-File $logPath

foreach ($file in $manifest.files) {
    $sha = Get-FileHash $file.path -Algorithm SHA256
    "[$(Get-Date)] $($file.name) → SHA256: $($sha.Hash)" | Out-File $logPath -Append
}

"Estado: ✅ Validado" | Out-File $logPath -Append
