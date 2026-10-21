# TrazaCafé: app Flutter

Un solo proyecto Flutter da dos productos:

| Producto | Plataforma | Quién lo usa |
|---|---|---|
| **App de campo** | Android (APK) | Técnicos y administradores de la cooperativa o exportadora. Funciona sin internet y sincroniza cuando hay señal. |
| **Verificador público** | Web (Firebase Hosting, `/v/{uid}`) | El comprador que escanea el QR del contenedor o del lote. Sin cuenta, en español o inglés. |
| **Eliminación de datos y privacidad** | Web (`/eliminar-datos`, `/privacidad`) | Productores que piden borrar sus datos y personas del equipo que eliminan su cuenta sin la app (requisito de Google Play). |

En la web solo se abren esas páginas (`lib/main.dart`). El manual para las personas que usan la app está en [`docs/guia-de-uso.md`](../docs/guia-de-uso.md); la infraestructura, en [`infra/README.md`](../infra/README.md).

## Estructura

| Carpeta | Contenido |
|---|---|
| `lib/screens/` | Pantallas: login, productores, fincas, visitas, entregas, temporadas, equipo, cultivos, lotes, contenedores, privacidad y solicitudes de eliminación, verificador (con sus textos en español e inglés en `verificador_textos.dart`) y las páginas web de eliminación de datos y privacidad |
| `lib/services/` | `ApiClient` (con un reintento si se corta la conexión), sincronización, fincas, fotos, mapas, correcciones, eliminación de datos (`eliminacion_service.dart`, también las llamadas sin sesión de la página web), compartir archivos, verificador y preferencias (tema e idioma, en `SharedPreferences`) |
| `lib/data/` | Base local SQLite con drift (`database.dart`; `database.g.dart` es generado) |
| `lib/domain/` | Reglas puras: geometría y polígonos, cédula nicaragüense, cultivos (`cultivos_generados.dart` sale de `schemas/cultivos.json`) |
| `lib/widgets/` | Formulario de entrega, mapa de Google, motivo de corrección, fotos, diálogo del QR del verificador |
| `test/` | Pruebas de pantallas, servicios y base local |
| `web/` | Página base del verificador (`index.html`, íconos) |

## Variables de compilación (`--dart-define`)

| Variable | Para qué | Valor por defecto |
|---|---|---|
| `API_URL` | URL de la API | `http://10.0.2.2:8080` (emulador). **Siempre** pasar la de Cloud Run al compilar el APK o la web. |
| `EAS_RED` | Red donde el verificador comprueba las attestations: `optimism-sepolia` u `optimism` | `optimism-sepolia` |
| `VERIFICADOR_URL` | Página que va en el QR | `https://trazacafe-dev.web.app` |
| `GOOGLE_MAPS_KEY` | Key de Google Map Tiles (solo Android) | la key restringida del proyecto |
| `ANDROID_CERT_SHA1` | SHA-1 del certificado que firma el APK (Google Map Tiles lo exige) | el certificado de depuración actual |
| `SOPORTE_EMAIL` | Correo de soporte de GoProduction que muestran las páginas de eliminación de datos y privacidad | vacío (no se muestra) |

## Comandos

```powershell
flutter pub get

# APK para los celulares del equipo
flutter build apk --release --dart-define=API_URL=https://trazacafe-api-85528878949.us-east4.run.app
# → build\app\outputs\flutter-apk\app-release.apk

# Verificador y páginas de eliminación de datos y privacidad (después: firebase deploy --only hosting, desde la raíz)
flutter build web --release --dart-define=API_URL=https://trazacafe-api-85528878949.us-east4.run.app

# Pruebas: en Windows, mejor archivo por archivo (ver dart_test.yaml)
powershell -ExecutionPolicy Bypass -File tool\probar.ps1
flutter analyze

# Después de cambiar las tablas de lib/data/database.dart
dart run build_runner build

# Después de cambiar schemas/cultivos.json (desde la raíz)
npm run cultivos-dart --workspace schemas

# Ícono de la app (assets/icon/icono.png)
dart run flutter_launcher_icons
```

## Firma del APK

El APK release se firma con el **certificado de depuración** de esta computadora (`%USERPROFILE%\.android\debug.keystore`). Su SHA-1 está registrado en Firebase (login con Google) y en la key de mapas.

- **Respalda ese archivo.** Si se pierde, los APK nuevos no podrán iniciar sesión ni cargar mapas hasta registrar el SHA-1 del certificado nuevo (`infra/README.md` §4).
- Para Play Store hace falta un certificado de subida propio y registrar el SHA-1 de Play App Signing.

## Base local

- **Versión actual del esquema:** 7 (productores anonimizados y tabla `ajustes`). Cada cambio sube `schemaVersion` y agrega su paso en `migration`, con su prueba en `test/temporadas_visitas_test.dart`.
- **Sin señal:** la app guarda todo en el celular y lo envía con **Sincronizar**.
- **Al sincronizar:** el servidor devuelve los datos de toda la organización y la app actualiza su copia, sin perder lo que todavía no se ha enviado.
- **Eliminaciones:** los productores y fincas que ya no vienen del servidor se borran del celular con sus fotos; a los anonimizados se les borran las fotos que quedaban en el celular. **Eliminar mi cuenta** deja el celular sin datos (`borrarTodoLocal`).
