# Compila el APK de release y lo copia con un nombre reconocible:
#   build\app\outputs\flutter-apk\TrazaCafe-<version>-<AAAA-MM-DD>.apk
#
#   powershell -ExecutionPolicy Bypass -File tool\apk.ps1   (desde app/)
#
# Antes, sube la version en pubspec.yaml (version: X.Y.Z+N): Android usa N
# para instalar encima del APK anterior.

$apiUrl = 'https://trazacafe-api-85528878949.us-east4.run.app'
$app = Resolve-Path "$PSScriptRoot\.."

$linea = Select-String -Path "$app\pubspec.yaml" -Pattern '^version:\s*([0-9.]+)\+' | Select-Object -First 1
if (-not $linea) { Write-Host 'No se encontro la version en pubspec.yaml' -ForegroundColor Red; exit 1 }
$version = $linea.Matches[0].Groups[1].Value

Push-Location $app
try {
  flutter build apk --release "--dart-define=API_URL=$apiUrl"
  if ($LASTEXITCODE -ne 0) { Write-Host 'Fallo la compilacion' -ForegroundColor Red; exit 1 }
  $carpeta = "$app\build\app\outputs\flutter-apk"
  $destino = "$carpeta\TrazaCafe-$version-$(Get-Date -Format 'yyyy-MM-dd').apk"
  Copy-Item "$carpeta\app-release.apk" $destino -Force
  Write-Host "APK: $destino"
} finally {
  Pop-Location
}
