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
# Opción 5 (rotar, para renovar o si la key se expuso): crea una key nueva, la
# guarda en el secreto, crea una revisión de Cloud Run para que la tome, y solo
# entonces borra la key vieja en GFW y deshabilita su versión en el secreto.
#
# Opción 3 (a prueba): /auth/apikey solo pide un token de sesión válido. Si
# entras a globalforestwatch.org con Google, puedes copiar el token de esa
# sesión desde el navegador (F12) y pegarlo aquí; no se muestra en pantalla.

$ErrorActionPreference = "Stop"
$proyecto = "trazacafe-dev"
$region = "us-east4"
$servicio = "trazacafe-api"
$cuentaApi = "trazacafe-api@$proyecto.iam.gserviceaccount.com"
$api = "https://data-api.globalforestwatch.org"

$opcion = Read-Host "¿Qué quieres hacer? [1] Registrar una cuenta nueva con correo  [2] Crear la key (ya tengo contraseña)  [3] Crear la key con el token de mi sesión del navegador  [4] Anotar el vencimiento de la key actual  [5] Rotar: key nueva y borrar la vieja"
$rotar = $opcion -eq "5"

# Versión vigente del secreto (o $null si no existe). En Windows PowerShell 5.1,
# "2>$null" con ErrorActionPreference=Stop corta el script si gcloud escribe
# en stderr (por ejemplo, el aviso de actualizaciones); por eso se baja a Continue.
function Version-Actual {
  $ErrorActionPreference = "Continue"
  $v = gcloud secrets versions describe latest --secret=gfw-api-key --project=$proyecto --format="value(name)" 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $v) { return $null }
  return ($v | Out-String).Trim().Split("/")[-1]
}

if ($rotar) {
  $versionAnterior = Version-Actual
  if (-not $versionAnterior) {
    Write-Host "No hay key guardada en gfw-api-key para rotar. Usa la opción 2." -ForegroundColor Red
    exit 1
  }
}

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

# Alias con fecha y hora: al rotar conviven dos keys un momento.
$alias = "trazacafe-api-$(Get-Date -Format 'yyyyMMdd-HHmm')"
$cuerpo = @{ alias = $alias; email = $correo; organization = "GoProduction"; domains = @() } | ConvertTo-Json
try {
  $respuesta = Invoke-RestMethod -Method Post "$api/auth/apikey" `
    -Headers @{ Authorization = "Bearer $token" } -ContentType "application/json" -Body $cuerpo
} catch {
  $token = $null
  Write-Host "GFW rechazó la solicitud: $($_.ErrorDetails.Message)" -ForegroundColor Red
  if ($opcion -eq "3") { Write-Host "El token de una sesión de Google no sirve o ya venció (dura poco): vuelve a copiarlo recién entrado." -ForegroundColor Yellow }
  exit 1
}
$dato = @($respuesta.data)[0]
$key = $dato.api_key

$archivo = New-TemporaryFile
try {
  [IO.File]::WriteAllText($archivo, $key)
  if (Version-Actual) {
    gcloud secrets versions add gfw-api-key --data-file="$archivo" --project=$proyecto | Out-Null
  } else {
    gcloud secrets create gfw-api-key --data-file="$archivo" --replication-policy=automatic --project=$proyecto | Out-Null
  }
} finally {
  Remove-Item $archivo -Force
  $key = $null
}
gcloud secrets add-iam-policy-binding gfw-api-key --project=$proyecto `
  --member="serviceAccount:$cuentaApi" --role=roles/secretmanager.secretAccessor | Out-Null

$vence = Anotar-Vencimiento ([string]$dato.expires_on)
Write-Host "La key nueva ($alias) quedó en Secret Manager (gfw-api-key). Vence el $vence." -ForegroundColor Green

if (-not $rotar) {
  $token = $null
  exit 0
}

# Revisión nueva de Cloud Run: sus instancias leen la versión "latest" del
# secreto al arrancar. Así nadie sigue usando la key vieja cuando se borre.
Write-Host "Creando una revisión de $servicio para que tome la key nueva..."
gcloud run services update $servicio --region=$region --project=$proyecto --update-labels="gfw-key=$vence" | Out-Null

# Borrar la key vieja en GFW (la que estaba en la versión anterior del secreto).
$anterior = (gcloud secrets versions access $versionAnterior --secret=gfw-api-key --project=$proyecto | Out-String).Trim()
try {
  Invoke-RestMethod -Method Delete "$api/auth/apikey/$anterior" -Headers @{ Authorization = "Bearer $token" } | Out-Null
  Write-Host "Key vieja borrada en GFW." -ForegroundColor Green
} catch {
  Write-Host "No se pudo borrar la key vieja en GFW: $($_.ErrorDetails.Message)" -ForegroundColor Red
  Write-Host "La key nueva ya está en uso. La vieja sigue activa en GFW hasta su vencimiento; pide ayuda para borrarla." -ForegroundColor Yellow
  $token = $null
  $anterior = $null
  exit 1
}
$token = $null
$anterior = $null

gcloud secrets versions disable $versionAnterior --secret=gfw-api-key --project=$proyecto | Out-Null
Write-Host "Listo: rotada. Versión $versionAnterior del secreto deshabilitada; la API usa la nueva." -ForegroundColor Green
