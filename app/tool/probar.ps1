# Corre cada archivo de prueba por separado y suma los resultados.
#
#   powershell -ExecutionPolicy Bypass -File tool\probar.ps1   (desde app/)
#
# En Windows, flutter_tester.exe a veces se cae a mitad de un archivo con
# 0xC0000005 (violación de acceso del motor, no de las pruebas). Las pruebas
# que faltaban salen como "did not complete" (le puede tocar a cualquier
# archivo). En ese caso el archivo se repite hasta 4 veces y
# se avisa. Una prueba que falla de verdad no se repite. CI corre en Linux.

$total = 0
$fallos = 0
foreach ($f in Get-ChildItem "$PSScriptRoot\..\test" -Filter *_test.dart | Sort-Object Name) {
  $reintentos = 0
  while ($true) {
    $salida = flutter test "test/$($f.Name)" 2>&1
    $ultimo = $salida | Select-Object -Last 1
    $caido = ($salida | Select-String -SimpleMatch 'did not complete' -Quiet) -and
             -not ($salida | Select-String -SimpleMatch '[E]' | Select-String -NotMatch 'did not complete' -Quiet)
    if (-not $caido -or $ultimo -match 'All tests passed' -or $reintentos -ge 4) { break }
    $reintentos++
  }
  $nota = if ($reintentos -gt 0) { " (flutter_tester se cayo; $reintentos reintento(s))" } else { '' }
  if ($ultimo -match '\+(\d+): All tests passed') {
    $total += [int]$Matches[1]
    Write-Host "OK    $($f.Name) ($($Matches[1]))$nota"
  } else {
    $fallos++
    Write-Host "FALLA $($f.Name): $ultimo$nota" -ForegroundColor Red
  }
}
Write-Host "TOTAL: $total pruebas, $fallos archivos con fallas"
if ($fallos -gt 0) { exit 1 }
