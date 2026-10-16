# Corre cada archivo de prueba por separado y suma los resultados.
# En Windows, `flutter test` con varios archivos a veces deja pruebas en
# "did not complete" (ver dart_test.yaml); por separado pasan siempre.
#
#   powershell -ExecutionPolicy Bypass -File tool\probar.ps1   (desde app/)

$total = 0
$fallos = 0
foreach ($f in Get-ChildItem "$PSScriptRoot\..\test" -Filter *_test.dart | Sort-Object Name) {
  $ultimo = (flutter test "test/$($f.Name)" 2>&1 | Select-Object -Last 1)
  if ($ultimo -match '\+(\d+): All tests passed') {
    $total += [int]$Matches[1]
    Write-Host "OK    $($f.Name) ($($Matches[1]))"
  } else {
    $fallos++
    Write-Host "FALLA $($f.Name): $ultimo" -ForegroundColor Red
  }
}
Write-Host "TOTAL: $total pruebas, $fallos archivos con fallas"
if ($fallos -gt 0) { exit 1 }
