# Crea una API key de Global Forest Watch / Global Nature Watch y la guarda en
# Secret Manager (secreto "gfw-api-key"). La contraseña y la key no se
# muestran en pantalla.
#
# Importante (guía oficial de GFW): la API solo acepta cuentas con correo y
# contraseña. Una cuenta creada con "Entrar con Google" no sirve, y se
# recomienda usar OTRO correo distinto al de esa cuenta de Google.
#
#   powershell -ExecutionPolicy Bypass -File infra\gfw-api-key.ps1
#
# Primera vez: elige "registrar"; llega un correo de Okta para crear la
# contraseña (revisa también el correo no deseado). Después vuelve a correr
# el script y elige "crear key".
#
# Al crear la key, el script anota su vencimiento en el secreto (vence=AAAA-MM-DD).
# La opción 4 anota el de la key que ya está guardada (pide la contraseña).
#
# Opción 3 (a prueba): /auth/apikey solo pide un token de sesión válido. Si
# entras a globalforestwatch.org con Google, puedes copiar el token de esa
# sesión desde el navegador (F12) y pegarlo aquí; no se muestra en pantalla.

$ErrorActionPreference = "Stop"
$proyecto = "trazacafe-dev"
$cuentaApi = "trazacafe-api@$proyecto.iam.gserviceaccount.com"
$api = "https://data-api.globalforestwatch.org"

$opcion = Read-Host "¿Qué quieres hacer? [1] Registrar una cuenta nueva con correo  [2] Crear la key (ya tengo contraseña)  [3] Crear la key con el token de mi sesión del navegador  [4] Anotar el vencimiento de la key actual"

if ($opcion -eq "1") {
  $nombre = Read-Host "Tu nombre"
  $correo = Read-Host "Correo para la cuenta (NO el de tu cuenta de Google en GFW)"
  $r = Invoke-RestMethod -Method Post "$api/auth/sign-up" -ContentType "application/json" `
    -Body (@{ name = $nombre; email = $correo } | ConvertTo-Json)
  Write-Host "Respuesta: $($r.status) $($r.message)"
  Write-Host "Revisa tu correo: Okta te enviará un enlace para crear la contraseña. Luego vuelve a correr este script y elige 2." -ForegroundColor Yellow
  exit 0
}

function Texto([Security.SecureString] $seguro) {
  [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro))
}

if ($opcion -eq "3") {
  $correo = Read-Host "Correo de tu cuenta (el de Google con que entraste)"
  $token = (Texto (Read-Host "Token de sesión (sin la palabra Bearer)" -AsSecureString)).Trim()
  if ($token -like "Bearer *") { $token = $token.Substring(7).Trim() }
} else {
  $correo = Read-Host "Correo de tu cuenta de GFW (la de correo y contraseña)"
  $clave = Texto (Read-Host "Contraseña" -AsSecureString)
  $token = (Invoke-RestMethod -Method Post "$api/auth/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body @{ username = $correo; password = $clave }).data.access_token
  $clave = $null
}

function Anotar-Vencimiento([string] $expira) {
  # AAAA-MM-DD como anotación del secreto: la consola y los recordatorios la
  # leen de los metadatos, sin tocar el valor de la key.
  $fecha = $expira.Substring(0, 10)
  gcloud secrets update gfw-api-key --update-annotations="vence=$fecha" --project=$proyecto | Out-Null
  return $fecha
}

if ($opcion -eq "4") {
  # La key que ya está en el secreto: GFW solo dice cuándo vence con un token de la cuenta dueña.
  $actual = (gcloud secrets versions access latest --secret=gfw-api-key --project=$proyecto | Out-String).Trim()
  try {
    $info = Invoke-RestMethod "$api/auth/apikey/$actual" -Headers @{ Authorization = "Bearer $token" }
  } catch {
    Write-Host "GFW rechazó la consulta: $($_.ErrorDetails.Message)" -ForegroundColor Red
    exit 1
  } finally {
    $token = $null
    $actual = $null
  }
  $fecha = Anotar-Vencimiento ([string]@($info.data)[0].expires_on)
  Write-Host "Listo: anotado vence=$fecha en el secreto gfw-api-key." -ForegroundColor Green
  exit 0
}

$cuerpo = @{ alias = "trazacafe-api"; email = $correo; organization = "GoProduction"; domains = @() } | ConvertTo-Json
try {
  $respuesta = Invoke-RestMethod -Method Post "$api/auth/apikey" `
    -Headers @{ Authorization = "Bearer $token" } -ContentType "application/json" -Body $cuerpo
} catch {
  Write-Host "GFW rechazó la solicitud: $($_.ErrorDetails.Message)" -ForegroundColor Red
  if ($opcion -eq "3") { Write-Host "El token de una sesión de Google no sirve o ya venció (dura poco): vuelve a copiarlo recién entrado." -ForegroundColor Yellow }
  exit 1
} finally {
  $token = $null
}
$dato = @($respuesta.data)[0]
$key = $dato.api_key

$archivo = New-TemporaryFile
try {
  [IO.File]::WriteAllText($archivo, $key)
  $existe = gcloud secrets describe gfw-api-key --project=$proyecto 2>$null
  if ($existe) {
    gcloud secrets versions add gfw-api-key --data-file="$archivo" --project=$proyecto | Out-Null
  } else {
    gcloud secrets create gfw-api-key --data-file="$archivo" --replication-policy=automatic --project=$proyecto | Out-Null
  }
} finally {
  Remove-Item $archivo -Force
}
gcloud secrets add-iam-policy-binding gfw-api-key --project=$proyecto `
  --member="serviceAccount:$cuentaApi" --role=roles/secretmanager.secretAccessor | Out-Null

$vence = Anotar-Vencimiento ([string]$dato.expires_on)

Write-Host "Listo: la key quedó en Secret Manager (gfw-api-key). Vence el $vence." -ForegroundColor Green
