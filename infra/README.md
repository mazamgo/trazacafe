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

- **Costo:** unos US$2.50 al mes por la versión de clave HSM, más las firmas (pocas al día).
- **Permisos:** la cuenta de servicio de la API necesita `roles/cloudkms.signerVerifier` y `roles/cloudkms.publicKeyViewer` sobre la clave.
- **Dirección:** la dirección Ethereum se deriva de la clave pública (`backend/src/kms.ts`); `npm run registrar-esquemas -- --direccion` la muestra junto con su saldo. Esa dirección necesita un poco de ETH en OP para el gas: en Sepolia, de un faucet.

### Attestations (Fase 2)

1. **Registrar los esquemas** con la misma clave: `npm run registrar-esquemas` (OP Sepolia) o `-- --red optimism` (OP Mainnet).
2. **Configurar la API** con `KMS_KEY_VERSION` (`projects/…/cryptoKeyVersions/1`), `EAS_RED` (`optimism-sepolia` u `optimism`) y, opcional, `RPC_URL`.
3. **Programar el worker:** Cloud Scheduler llama cada hora a `POST /v1/tareas/attestations` con el mismo token OIDC que el chequeo satelital (`backend/src/atestador.ts`).

El worker firma en cuatro olas, una transacción por ola, para que cada attestation pueda apuntar a la anterior:

| Ola | Qué firma | A qué apunta |
|---|---|---|
| 1 | Versiones del lindero (`Finca`) | La versión anterior |
| 2 | `Chequeo` satelital, `Verificacion` (visita) y `Entrega` | Su versión de finca |
| 3 | `Lote` | Lleva los UIDs de sus entregas |
| 4 | `Exportacion` | Lleva los UIDs de sus lotes; solo cerrada y con la referencia de la DDS |

- **Fallos:** si una ola falla, se reintenta a los 15 minutos.
- **Registro:** lo firmado queda en la tabla `attestaciones` (red y transacción).
- **Privacidad:** en la blockchain solo van ids, hashes, cantidades y textos de catálogo, nunca nombres de personas.

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
- **App:** **Nueva finca** siempre muestra el cultivo. Con un solo cultivo activado aparece fijo, y al administrador se le indica dónde activar más. Con varios, se elige con el selector Café | Cacao.
- **Cambiar cultivo:** en el detalle de la finca, solo mientras no tenga entregas ni esté atestada (`PUT /v1/fincas/:id/cultivo`; necesita señal si la finca ya se envió). Las visitas pasan a la temporada del cultivo nuevo.
- **Attestations:** los esquemas `Finca` y `Entrega` incluyen `cultivo`. Todavía no están registrados en la blockchain.

## 4f. Lotes (Fase 2)

- **Quién:** solo administradores, desde la app (menú ⋮ → **Lotes**). Necesita señal: el lote se arma con las entregas de todo el equipo, que están en el servidor.
- **Reglas EUDR** (`backend/src/lotes.ts`). Un lote es de **un cultivo y una temporada**, y una entrega va a un solo lote. La API rechaza el lote (422, diciendo qué entrega y por qué) si una entrega:
  - es de una finca en **rojo**;
  - es de una finca **sin visita de verificación** en esa temporada;
  - es de otro cultivo o de otra temporada;
  - ya está en otro lote.
- **Avisos** (se guardan con el lote, no lo impiden):
  - **Volumen:** el peso del lote supera en más de un 10 % lo que rinden sus entregas. Por ejemplo, 500 kg de uva rinden unos 100 kg de pergamino.
  - **Rendimiento:** una finca entrega en la temporada más kg por hectárea de lo razonable (café 2,500 kg oro/ha; cacao 2,000 kg seco/ha).
  - **Satélite:** hay fincas sin chequeo satelital verde.
- **Factores de rendimiento** en `schemas/cultivos.json` (`factorExportable` por estado: kg de café oro o cacao seco por kg). Son aproximaciones que hay que ajustar con datos del piloto:
  - café: uva 0.16, pergamino 0.8;
  - cacao: baba 0.38, fermentado 0.45.
- **Deshacer:** un lote que no está en la blockchain ni en un contenedor se puede deshacer, y sus entregas quedan libres. Una finca con entregas en un lote no se puede borrar.
- Cada lote encola su attestation (`Lote`). El esquema EAS ahora incluye cultivo, temporada y estado.

## 4g. Contenedores (Fase 2)

- **Quién:** solo administradores, desde el menú ⋮ → **Contenedores**. Necesita señal.
- **Reglas** (`backend/src/exportaciones.ts`):
  - un contenedor lleva lotes de **un solo cultivo**, y un lote va a un solo contenedor;
  - un lote embarcado ya no se puede deshacer.
- **Datos:** código interno, comprador y destino. El número de contenedor (ISO 6346, con el **dígito de control validado**), la fecha de embarque y la referencia de la DDS de TRACES se pueden completar después.
- **Estados:**
  - **abierto:** se edita o se deshace, y sus lotes quedan libres;
  - **cerrado:** ya no cambia. Se cierra en el paso del paquete EUDR, que exigirá todas las fincas en verde y encolará la attestation `Exportacion`.
- **Resumen de origen** para el paquete: fincas, hectáreas oficiales, entregas y cuántas fincas no tienen chequeo satelital verde.

## 4h. Paquete EUDR (Fase 2)

Desde la tarjeta del contenedor (`backend/src/paquete.ts`):

- **GeoJSON para TRACES** (`GET /v1/exportaciones/:id/geojson`): una Feature por finca de origen con su lindero vigente (WGS84, 8 decimales; punto si mide menos de 4 ha). Propiedades: `ProducerCountry` (NI), `ProductionPlace` (finca y comunidad) y `Area` (ha oficiales). `ProducerName` solo con `?productores=1`, porque es dato personal (Ley 787). **Pendiente:** validar el archivo subiéndolo a TRACES (entorno de aceptación) antes del primer envío real.
- **PDF para el comprador** (`GET /v1/exportaciones/:id/pdf`): envío, cumplimiento (corte 31/12/2020, chequeo satelital, visitas), lotes y fincas con su huella geoHash. No lleva nombres de productores.
- **Cerrar** (`POST /v1/exportaciones/:id/cerrar`): exige el número de contenedor y **todas las fincas en verde**; si no, responde 409 con los motivos. Al cerrar, encola la attestation `Exportacion`. Cerrado, solo se puede anotar la referencia de la DDS, mientras la attestation no esté firmada.
- En la app, el PDF y el GeoJSON se comparten con el menú del celular (WhatsApp, correo, Drive) usando `share_plus`.

## 5. Backend en Cloud Run (ya hecho)

Endpoints:
- Acceso y sincronización: `POST /v1/activar`, `POST /v1/sync` (productores, fincas, versiones de lindero, visitas, entregas, fotos), `GET /v1/datos` (todo lo de la organización, con sus cultivos), `POST /v1/fotos/:id/subida`.
- Fincas: `DELETE /v1/fincas/:id`, `POST /v1/fincas/:id/chequeo`, `PUT /v1/fincas/:id/cultivo`.
- Organización y temporadas: `GET /v1/organizacion`, `PUT /v1/organizacion/cultivos`, `GET|POST /v1/temporadas`.
- Lotes (administradores): `GET|POST /v1/lotes`, `GET /v1/lotes/disponibles?cultivo=&temporadaId=`, `DELETE /v1/lotes/:id`.
- Contenedores (administradores): `GET|POST /v1/exportaciones`, `PATCH|DELETE /v1/exportaciones/:id`, `GET /v1/exportaciones/:id/geojson|pdf`, `POST /v1/exportaciones/:id/cerrar`.
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
