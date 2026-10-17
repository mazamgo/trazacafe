# Infraestructura en Google Cloud

Estado y comandos del entorno del MVP. Los pasos marcados **ya hecho** existen en el proyecto `trazacafe-dev`; los demás crean recursos que pueden cobrar.

```powershell
$PROYECTO = "trazacafe-dev"
$REGION   = "us-east4"                      # Virginia, la más cercana a Nicaragua
$SQL      = "trazacafe-dev-instance"
```

## 1. Proyecto, facturación y presupuesto (ya hecho)

- Proyecto `trazacafe-dev` en el **plan Blaze** (pago por uso), vinculado a la cuenta de facturación "Firebase Payment". Mientras el uso no pase las cuotas gratis, no se cobra.
- **Alerta de presupuesto de US$5 al mes** con avisos por correo al 50 %, 90 % y 100 %. Ojo: las alertas **avisan, no cortan** el servicio.

APIs que se irán activando según se usen:

```powershell
gcloud services enable run.googleapis.com cloudkms.googleapis.com cloudbuild.googleapis.com `
  artifactregistry.googleapis.com secretmanager.googleapis.com cloudtasks.googleapis.com `
  cloudscheduler.googleapis.com --project=$PROYECTO
```

## 2. Cloud SQL (PostgreSQL 18 + PostGIS) (ya hecho)

Creada desde **Firebase SQL Connect** (antes Data Connect) para usar la **prueba gratis de 3 meses**. Al terminar la prueba se cobra la tarifa normal de Cloud SQL (desde ~US$9–10 al mes); la consola de Firebase muestra la fecha.

| Dato | Valor |
|---|---|
| Instancia | `trazacafe-dev:us-east4:trazacafe-dev-instance` (db-f1-micro, 10 GB) |
| Base de datos | `trazacafe-dev-database` |
| Autenticación | **IAM de Google, sin contraseñas** (`cloudsql.iam_authentication=on`) |

El backend se conecta con el conector oficial (`@google-cloud/cloud-sql-connector`) usando la identidad de Google del proceso: tu correo en desarrollo y la cuenta de servicio en Cloud Run. Configúralo en `backend/.env` (ver `.env.example`) y, una vez por computadora:

```powershell
gcloud auth application-default login
cd backend; npm run migrate        # aplica db/migrations y activa PostGIS
```

Para dar acceso a otra persona del equipo de desarrollo:

```powershell
gcloud sql users create persona@gmail.com --instance=$SQL --type=cloud_iam_user --project=$PROYECTO
gcloud projects add-iam-policy-binding $PROYECTO --member=user:persona@gmail.com --role=roles/cloudsql.instanceUser
gcloud projects add-iam-policy-binding $PROYECTO --member=user:persona@gmail.com --role=roles/cloudsql.client
# y dentro de la base: GRANT trazacafe_app TO "persona@gmail.com";
```

## 3. Clave de firma en Cloud KMS (secp256k1)

La clave privada que firma las attestations se genera y vive dentro de KMS; nadie puede extraerla.

```powershell
gcloud kms keyrings create trazacafe --location=$REGION
gcloud kms keys create atestador --keyring=trazacafe --location=$REGION `
  --purpose=asymmetric-signing --default-algorithm=ec-sign-secp256k1-sha256 --protection-level=hsm
```

La dirección Ethereum de la clave se deriva de su clave pública (lo hará el worker en la semana 4). Esa dirección necesita un poco de ETH en OP para pagar el gas.

## 4. Firebase (login y hosting del verificador)

**Ya hecho:** el proyecto `trazacafe-dev` existe y la app tiene sus apps Android y Web registradas (`app/lib/firebase_options.dart`, `app/android/app/google-services.json`).

**Inicio de sesión: solo con Google.** El proveedor Google está activado; Firebase creó el cliente OAuth web (su ID está en `googleWebClientId` de `firebase_options.dart`) y el de Android (paquete + SHA-1). El proveedor de correo/contraseña sigue activado en la consola pero la app no lo usa; se puede desactivar.

### Restricciones de las API keys (ya aplicadas)

Las claves de `firebase_options.dart` son públicas (el repo es público), así que están limitadas:

| Key | Solo funciona desde | Servicios permitidos |
|---|---|---|
| Android | paquete `com.goproduction.trazacafe` firmado con el certificado de depuración (SHA-1 `A5:F0:24:…:CF:83`) | Identity Toolkit, Secure Token, Firebase Installations, Firebase Storage |
| Navegador | `trazacafe-dev.web.app`, `trazacafe-dev.firebaseapp.com`, `localhost:5000` | los mismos |

- **Al publicar en Play Console** Google firma la app con otro certificado. Copia su SHA-1 de *Play Console → Configuración → Integridad de la app* y agrégalo; si no, el login falla en la app publicada:

  ```powershell
  gcloud services api-keys update 0a30f3fc-8ed7-4465-89a8-ec1ea000d323 --project=trazacafe-dev --append `
    '--allowed-application=sha1_fingerprint=<SHA1_SIN_DOS_PUNTOS>,package_name=com.goproduction.trazacafe'
  firebase apps:android:sha:create 1:85528878949:android:15e87427c4ad8ad5b68b8c <SHA1> --project trazacafe-dev
  ```

- **Otra computadora de desarrollo** tiene otro certificado de depuración: agrega su SHA-1 igual que arriba.
- **Web en desarrollo**: corre el verificador en el puerto permitido con `flutter run -d chrome --web-port 5000`.
- Si se usa un servicio nuevo de Firebase (por ejemplo Firestore), hay que agregarlo con `--api-target`.

### Acceso por invitación

Cualquier cuenta de Google puede abrir la app, pero solo los correos invitados reciben una organización y un rol (custom claims `organizacionId` y `rol`). Sin invitación la app muestra "Tu cuenta no está autorizada" y la API responde 403.

| Rol | Puede |
|---|---|
| `admin` | Invitar y quitar personas (pantalla **Equipo**), elegir los cultivos (**Cultivos**), crear temporadas, todo lo del técnico |
| `tecnico` | Registrar productores, fincas, fotos y sincronizar |

Organización de prueba ya creada: **GoProduction (pruebas)**, con `mauricio.zambrana.g@gmail.com` invitado como administrador.

Para una organización nueva (cooperativa, exportadora o beneficio de café o cacao), se crea con su primer administrador:

```powershell
cd backend
npm run crear-organizacion -- --nombre "Cooperativa Ejemplo R.L." --admin gerente@gmail.com --cultivos cafe,cacao
```

`--cultivos` es opcional (por defecto, solo `cafe`). El administrador puede cambiarlos después desde la app (menú ⋮ → **Cultivos**), pero no puede quitar un cultivo que ya tiene fincas.

El administrador entra con "Entrar con Google" usando ese correo y desde **Equipo** invita a sus técnicos. Quitar a alguien le borra los permisos y cierra sus sesiones al instante (la API verifica tokens revocados). Necesita la base de datos (paso 2).

## 4b. Fotos en Firebase Storage (ya hecho)

| Dato | Valor |
|---|---|
| Bucket | `trazacafe-dev.firebasestorage.app` en **US-EAST1** (región con cuota gratis de Storage) |
| Ruta | `organizaciones/{organizacionId}/fotos/{fotoId}.jpg` |
| Reglas | `storage.rules` en la raíz: cada organización lee y crea solo en su carpeta; JPEG < 5 MB; nada se reemplaza ni se borra desde la app |

Flujo: la app sincroniza el hash de la foto, sube el archivo directo a Storage y llama a `POST /v1/fotos/:id/subida`; la API descarga el archivo, compara su SHA-256 y solo entonces guarda `storage_path`. Si no coincide, lo borra. La cuenta de servicio de la API tiene `storage.objectAdmin` sobre el bucket.

Publicar cambios en las reglas: `firebase deploy --only storage` (desde la raíz).

## 4c. Mapas: Google Map Tiles (ya hecho)

- API `tile.googleapis.com` activada; mosaicos **satelitales con calles** (`mapType: satellite` + `layerRoadmap`).
- Key "TrazaCafe mapas (Android)" (`87275de0-…`) limitada al paquete `com.goproduction.trazacafe` + SHA-1 de depuración y solo a `tile.googleapis.com`. Está en `app/lib/mapas_config.dart`; la app envía `X-Android-Package` y `X-Android-Cert` en cada petición.
- Cuota gratis: **100,000 mosaicos al mes**; un técnico marcando una finca usa del orden de cientos.
- La sesión dura ~2 semanas y se guarda en el celular; Google solo permite la caché temporal del teléfono, no descargar zonas completas.
- **Al publicar en Play Store** agrega el SHA-1 de Play App Signing a esta key (como en la sección 4) y compila con `--dart-define=ANDROID_CERT_SHA1=<SHA1>`.
- La app muestra "Google" y el copyright de las imágenes visibles (`/tile/v1/viewport`), como exigen las políticas de Google. Para producción conviene usar el logo oficial de Google en vez del texto.

## 4d. Temporadas, visitas y chequeo satelital

- **Temporadas:** cada organización crea las suyas (menú ⋮ → Temporadas, solo administradores). Una temporada puede ser para **todos los cultivos** o **solo para uno** (por ejemplo, la cosecha de cacao). No pueden traslaparse dentro del mismo cultivo, pero una de cacao sí puede cruzarse con la general. Si existen las dos, las entregas y visitas de cacao van a la de cacao. Las entregas y visitas que llegan sin temporada se asignan solas al crearla.
- **Visita de verificación:** al menos una foto y, si cambió el lindero, uno nuevo. El lindero anterior queda en `fincas_versiones` y cada versión se atesta con su propio número.
- **Aviso:** si la finca no tiene visita en la temporada actual, o está en rojo, la app avisa al registrar una entrega. En la semana 4, el lote de exportación rechazará esas entregas.
- **Chequeo satelital** (`backend/src/deforestacion.ts`): consulta la Data API de Global Forest Watch.
  - **Datos:** pérdida de cobertura (`umd_tree_cover_loss`, años > 2020, densidad ≥ 30 %) y alertas integradas (`gfw_integrated_alerts` posteriores al 31/12/2020, confianza nominal o alta).
  - **Resultado:** verde = nada; amarillo = menos de 0.1 ha; rojo = 0.1 ha o más. Las fincas de un solo punto se revisan como un círculo de su área.
  - **Programación:** Cloud Scheduler `chequeo-deforestacion` (us-east4) llama todos los días a las 6:00 (hora de Managua) a `POST /v1/tareas/chequeo-deforestacion`, con un token OIDC de la cuenta `trazacafe-tareas@…`. Cada día revisa hasta 50 fincas que aún no tienen chequeo de su lindero vigente en la temporada actual; en la práctica, cada finca una vez por temporada.
  - **Revisión a mano:** el administrador puede revisar una finca en el momento desde la app (`POST /v1/fincas/:id/chequeo`).
- **API key de GFW:** con tu cuenta de globalforestwatch.org creada (con correo, no con Google), ejecuta `powershell -ExecutionPolicy Bypass -File infra\gfw-api-key.ps1`. El script la guarda en Secret Manager (`gfw-api-key`). Después:

  ```powershell
  gcloud run deploy trazacafe-api --image=<imagen actual> --region=$REGION --project=$PROYECTO --set-secrets=GFW_API_KEY=gfw-api-key:latest
  ```

  Sin la key, la tarea responde 503 y no marca ninguna finca. La key vence al año: vuelve a correr el script.

## 4e. Cultivos (café y cacao)

- **Datos:** `organizaciones.cultivos`, `fincas.cultivo` y `temporadas.cultivo` (migración `008_cultivos.sql`, aplicada el 16/10/2026). Las fincas anteriores quedaron como café.
- **Validación:** la API rechaza (422) las fincas de un cultivo que la organización no tiene activado y las entregas cuyo estado no corresponde al cultivo de su finca (por ejemplo, cacao en `uva`).
- **App:** el selector Café | Cacao aparece en **Nueva finca** solo cuando la organización tiene activado más de un cultivo. Por ahora, el cultivo de una finca ya registrada no se puede cambiar.
- **Attestations:** los esquemas `Finca` y `Entrega` incluyen `cultivo`. Todavía no están registrados en la blockchain.

## 5. Backend en Cloud Run (ya hecho)

Endpoints:
- Acceso y sincronización: `POST /v1/activar`, `POST /v1/sync` (productores, fincas, versiones de lindero, visitas, entregas, fotos), `GET /v1/datos` (todo lo de la organización, con sus cultivos), `POST /v1/fotos/:id/subida`.
- Fincas: `DELETE /v1/fincas/:id`, `POST /v1/fincas/:id/chequeo`.
- Organización y temporadas: `GET /v1/organizacion`, `PUT /v1/organizacion/cultivos`, `GET|POST /v1/temporadas`.
- Equipo: `GET|POST|DELETE /v1/invitaciones`.
- Tareas programadas: `POST /v1/tareas/chequeo-deforestacion`.

**URL de la API:** https://trazacafe-api-85528878949.us-east4.run.app

| Dato | Valor |
|---|---|
| Servicio | `trazacafe-api` en us-east4, de 0 a 2 instancias, 512 MB (sin uso no cobra) |
| Cuenta de servicio | `trazacafe-api@trazacafe-dev.iam.gserviceaccount.com` con solo `cloudsql.client`, `cloudsql.instanceUser` y `firebaseauth.admin` |
| Usuario de la base | `trazacafe-api@trazacafe-dev.iam` (IAM, rol `trazacafe_app`: solo datos) |
| Imágenes | Artifact Registry `us-east4-docker.pkg.dev/trazacafe-dev/trazacafe/backend` |
| Variables | `INSTANCE_CONNECTION_NAME`, `DB_NAME`, `DB_USER`, `FIREBASE_PROJECT_ID`, `STORAGE_BUCKET` |

La URL es pública (`allUsers` como invocador) porque la app la llama directamente; la API exige el token de Firebase en cada `/v1/*`. `.gcloudignore` limita lo que se sube a Cloud Build a `package*.json`, `schemas/` y `backend/`.

Para publicar una versión nueva del backend (desde la raíz del repo):

```powershell
$IMAGEN = "us-east4-docker.pkg.dev/$PROYECTO/trazacafe/backend:$(git rev-parse --short HEAD)"
gcloud builds submit . --config backend/cloudbuild.yaml --substitutions="_IMAGEN=$IMAGEN" --region=$REGION --project=$PROYECTO
gcloud run deploy trazacafe-api --image=$IMAGEN --region=$REGION --project=$PROYECTO
```

`gcloud run deploy` conserva la cuenta de servicio, las variables y los límites de la primera vez. Si hay migraciones nuevas, aplícalas antes con `npm run migrate`.

Ver errores: `gcloud run services logs read trazacafe-api --region=$REGION --project=$PROYECTO --limit=50`

### App apuntando a la API

```powershell
cd app
flutter build apk --release --dart-define=API_URL=https://trazacafe-api-85528878949.us-east4.run.app
```

El APK release va firmado con el certificado de depuración (el SHA-1 registrado). Para Play Console hace falta un certificado de subida propio y agregar el SHA-1 de Play App Signing (sección 4).

## 6. Verificador en Firebase Hosting

```powershell
cd app
flutter build web --release
firebase init hosting     # carpeta pública: build/web, SPA: sí
firebase deploy --only hosting
```
