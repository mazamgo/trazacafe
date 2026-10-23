# Revisión de seguridad (Fase 4) — 23/10/2026

Alcance: API (`backend/`), reglas de Storage, rutas públicas (verificador y página de eliminación de datos), Firebase Hosting, API keys, Firebase Auth y secretos del repositorio. Se revisó el código y la configuración de `trazacafe-dev` (solo lectura). Antes de producción (`trazacafe-prod`) hay que repetir la revisión de configuración en el proyecto nuevo.

## Resumen

| # | Hallazgo | Gravedad | Estado |
|---|---|---|---|
| 1 | Una API key de Android creada por Firebase (`776203a4…`, `AIzaSyBYZsVe…`) **no tiene restricción de app** y permite 27 servicios. Está en `google-services.json`, que es público en GitHub. | Media | **Pendiente: requiere tu aprobación** (configuración de Google Cloud) |
| 2 | El límite de solicitudes de eliminación por IP se podía saltar mandando un encabezado `X-Forwarded-For` falso (`trustProxy: true` toma la primera IP, que la escribe el cliente). Permitía llenar de solicitudes falsas a las cooperativas. | Media | **Corregido**: solo se confía en el frontal de Cloud Run. Prueba nueva. |
| 3 | Los errores internos (500) devolvían el mensaje del error tal cual: podía traer SQL, nombres de tablas o datos (por ejemplo, una cédula en un error de llave duplicada). | Media-baja | **Corregido**: mensaje genérico; el detalle queda solo en el log. Prueba nueva. |
| 4 | Las páginas públicas de Hosting (`/eliminar-datos`, `/privacidad`, `/v/…`) se podían mostrar dentro de otro sitio (clickjacking sobre "Eliminar mi cuenta"). | Baja | **Corregido en `firebase.json`**: `X-Frame-Options: DENY`, `frame-ancestors 'none'`, `nosniff` y `Referrer-Policy`. **Falta publicar Hosting.** |
| 5 | Firebase Auth tiene activado **correo y contraseña**, que la app no usa. Con una key pública se pueden crear cuentas basura. La API ya las rechaza (exige correo verificado y una invitación). | Baja | **Pendiente: requiere tu aprobación** (desactivarlo en Firebase) |
| 6 | El mapa de IPs del límite crecía sin tope en memoria. | Baja | **Corregido**: se limpia cuando pasa de 10 000 IPs. |
| 7 | A una persona a quien se le quita el acceso, Storage le sigue aceptando su token hasta 1 hora (las reglas no comprueban la revocación; la API sí). Solo puede leer fotos de su organización, no subir nada que la API acepte sin el hash. | Baja | Aceptado. Se cierra con App Check (Fase 4). |
| 8 | `localhost` está entre los dominios autorizados de Firebase Auth. | Informativo | Quitarlo en `trazacafe-prod`. |

## Lo que está bien (no requiere cambios)

- **Tokens:** `verifyIdToken(token, true)` rechaza tokens revocados al instante y exige correo verificado (`backend/src/server.ts`). Al quitar el acceso se borran los claims y se revocan las sesiones.
- **Roles:** todas las rutas de datos pasan por `activo()`. Las de administrador (lotes, contenedores, equipo, temporadas, cultivos, eliminaciones) exigen `soloAdmin`. Las pruebas cubren el 403 del técnico.
- **Aislamiento entre organizaciones:** cada consulta por id filtra por la organización del token (`repo.ts`, `correcciones.ts`, `eliminacion.ts`, `cobros.ts`). La sincronización rechaza fincas, visitas, entregas y fotos de otra organización (`AccesoDenegado`) y no sobrescribe productores ajenos.
- **SQL:** consultas parametrizadas; los nombres de columnas o tablas dinámicos salen de listas fijas (`actualizarExportacion`, el worker).
- **Tareas programadas:** token OIDC de Cloud Scheduler con audiencia y cuenta de servicio verificadas.
- **Rutas públicas:** el verificador solo devuelve lo firmado y sin datos personales (ubicación redondeada a ~1 km). La solicitud de eliminación tiene validación, campo trampa y límite por IP. CORS abierto solo en las rutas web, con sesión por encabezado (sin cookies).
- **Storage:** solo la organización del token lee o sube a su carpeta, solo `.jpg` de menos de 5 MB, nunca reemplazar ni borrar desde la app. Lo demás está cerrado.
- **Fotos:** la API acepta el archivo solo si su SHA-256 coincide con el registrado.
- **Secretos:** `.env`, llaves y cuentas de servicio están en `.gitignore`, y no hay ninguno en el historial. La key de GFW vive en Secret Manager y la clave de firma en Cloud KMS (no se puede extraer). Las keys de Firebase y de mapas del repositorio son públicas por diseño y están restringidas, salvo la del hallazgo 1.

## Pendientes que necesitan tu aprobación

1. **Restringir la key `776203a4`** igual que la otra key de Android: solo el paquete `com.goproduction.trazacafe` con su SHA-1 y solo Identity Toolkit, Secure Token, Firebase Installations y Firebase Storage. La app usa la otra key (`firebase_options.dart`), así que no debería afectarla.

   ```powershell
   gcloud services api-keys update 776203a4-<resto del uid> --project=trazacafe-dev `
     --allowed-application=sha1_fingerprint=A5F0249A42CB1D027841058E797690ACCC82CF83,package_name=com.goproduction.trazacafe `
     --api-target=service=identitytoolkit.googleapis.com --api-target=service=securetoken.googleapis.com `
     --api-target=service=firebaseinstallations.googleapis.com --api-target=service=firebasestorage.googleapis.com
   ```
2. **Desactivar "Correo electrónico/contraseña"** en *Firebase Console → Authentication → Método de acceso*.
3. **Publicar la API** (corrige los hallazgos 2, 3 y 6) y **Hosting** (hallazgo 4). Después de publicar la API, confirmar en los logs que `remoteAddress` es la IP real del cliente. Si algún día se pone un balanceador de carga delante de Cloud Run, hay dos saltos y `trustProxy` debe confiar en ambos.

## Para la revisión de producción (`trazacafe-prod`)

- Keys nuevas, restringidas desde el inicio (incluido el SHA-1 de Play App Signing).
- Solo el proveedor Google en Firebase Auth, y sin `localhost`.
- Firebase App Check con Play Integrity en la API y en Storage.
- Alertas de presupuesto y de errores 5xx en Cloud Run.
