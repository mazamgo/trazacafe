# Infraestructura en Google Cloud

Comandos para montar el entorno del MVP. **Crean recursos que cobran**: Cloud SQL cuesta unos US$10–30 al mes aunque no se use. Ejecútalos en orden y revisa cada uno.

Variables usadas abajo (PowerShell):

```powershell
$PROYECTO = "trazacafe-dev"        # ID único en Google Cloud
$REGION   = "us-central1"          # o us-east1; la más cercana con buen precio
$SQL      = "trazacafe-db"
```

## 1. Proyecto y APIs

```powershell
gcloud projects create $PROYECTO --name="TrazaCafe"
gcloud config set project $PROYECTO
# Vincula la facturación en la consola: https://console.cloud.google.com/billing
gcloud services enable sqladmin.googleapis.com run.googleapis.com cloudkms.googleapis.com `
  cloudbuild.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com `
  cloudtasks.googleapis.com cloudscheduler.googleapis.com storage.googleapis.com
```

## 2. Cloud SQL (PostgreSQL + PostGIS)

```powershell
gcloud sql instances create $SQL --database-version=POSTGRES_16 --region=$REGION `
  --edition=ENTERPRISE --tier=db-f1-micro --storage-size=10GB
gcloud sql databases create trazacafe --instance=$SQL
gcloud sql users create trazacafe --instance=$SQL --prompt-for-password
```

PostGIS se activa con la primera migración (`CREATE EXTENSION postgis`).

Para desarrollo local, conecta con el [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy) y aplica las migraciones:

```powershell
cloud-sql-proxy "${PROYECTO}:${REGION}:${SQL}" --port 5432
# en otra terminal, con DATABASE_URL en backend/.env:
cd backend; npm run migrate
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

```powershell
firebase projects:addfirebase $PROYECTO
cd app
flutterfire configure --project=$PROYECTO --platforms=android,web
```

En la consola de Firebase activa **Authentication → Correo/contraseña**.

## 5. Backend en Cloud Run

```powershell
gcloud artifacts repositories create trazacafe --repository-format=docker --location=$REGION
$IMAGEN = "$REGION-docker.pkg.dev/$PROYECTO/trazacafe/backend"
gcloud builds submit --tag $IMAGEN --file backend/Dockerfile .
gcloud run deploy trazacafe-api --image=$IMAGEN --region=$REGION `
  --add-cloudsql-instances="${PROYECTO}:${REGION}:${SQL}" `
  --set-env-vars="FIREBASE_PROJECT_ID=$PROYECTO" `
  --set-secrets="DATABASE_URL=database-url:latest" --allow-unauthenticated
```

`--allow-unauthenticated` deja la URL accesible; la API exige el token de Firebase en cada petición de `/v1/*`. Guarda `DATABASE_URL` en Secret Manager antes (`gcloud secrets create database-url --data-file=-`). En Cloud Run la conexión va por socket: `postgres://trazacafe:CLAVE@/trazacafe?host=/cloudsql/PROYECTO:REGION:trazacafe-db`.

## 6. Verificador en Firebase Hosting

```powershell
cd app
flutter build web --release
firebase init hosting     # carpeta pública: build/web, SPA: sí
firebase deploy --only hosting
```
