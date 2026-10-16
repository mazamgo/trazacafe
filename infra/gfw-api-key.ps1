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
# contraseña. Después vuelve a correr el script y elige "crear key".

$ErrorActionPreference = "Stop"
$proyecto = "trazacafe-dev"
$cuentaApi = "trazacafe-api@$proyecto.iam.gserviceaccount.com"
$api = "https://data-api.globalforestwatch.org"

$opcion = Read-Host "¿Qué quieres hacer? [1] Registrar una cuenta nueva con correo  [2] Crear la key (ya tengo contraseña)"

if ($opcion -eq "1") {
  $nombre = Read-Host "Tu nombre"
  $correo = Read-Host "Correo para la cuenta (NO el de tu cuenta de Google en GFW)"
  $r = Invoke-RestMethod -Method Post "$api/auth/sign-up" -ContentType "application/json" `
    -Body (@{ name = $nombre; email = $correo } | ConvertTo-Json)
  Write-Host "Respuesta: $($r.status) $($r.message)"
  Write-Host "Revisa tu correo: Okta te enviará un enlace para crear la contraseña. Luego vuelve a correr este script y elige 2." -ForegroundColor Yellow
  exit 0
}

$correo = Read-Host "Correo de tu cuenta de GFW (la de correo y contraseña)"
$claveSegura = Read-Host "Contraseña" -AsSecureString
$clave = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($claveSegura))

$token = (Invoke-RestMethod -Method Post "$api/auth/token" `
  -ContentType "application/x-www-form-urlencoded" `
  -Body @{ username = $correo; password = $clave }).data.access_token
$clave = $null

$cuerpo = @{ alias = "trazacafe-api"; email = $correo; organization = "GoProduction"; domains = @() } | ConvertTo-Json
$respuesta = Invoke-RestMethod -Method Post "$api/auth/apikey" `
  -Headers @{ Authorization = "Bearer $token" } -ContentType "application/json" -Body $cuerpo
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

Write-Host "Listo: la key quedó en Secret Manager (gfw-api-key). Vence el $($dato.expires_on)." -ForegroundColor Green
