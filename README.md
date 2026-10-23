# TrazaCafé

Trazabilidad de café y cacao nicaragüenses para el reglamento europeo contra la deforestación (EUDR). Cada paso de la cadena de custodia (finca → entrega → lote → exportación) se registra como *attestation* de [EAS](https://attest.org) en el OP Stack (hoy en OP Sepolia, la red de pruebas; en producción, OP Mainnet). El comprador lo verifica escaneando un QR.

## Documentación

| Documento | Para quién | Qué tiene |
|---|---|---|
| [docs/guia-de-uso.md](docs/guia-de-uso.md) | Técnicos y administradores | Manual de la app, paso a paso |
| [infra/README.md](infra/README.md) | Quien instala o mantiene el sistema | Google Cloud, Firebase, base de datos, API, satélite, attestations, verificador y cómo desplegar |
| [app/README.md](app/README.md) | Desarrolladores de la app | Estructura, variables de compilación, APK, web y pruebas |
| [backend/.env.example](backend/.env.example) | Desarrolladores de la API | Todas las variables de entorno, explicadas |
| [docs/plan-nicaragua-multicultivo.md](docs/plan-nicaragua-multicultivo.md) | Todos | Plan vigente y avance por fase |
| [docs/plan-mvp-trazabilidad-cafe.md](docs/plan-mvp-trazabilidad-cafe.md) | Referencia | MVP original |

Cada cambio en la app o la API actualiza en el mismo commit la documentación que afecta (ver `CLAUDE.md`).

## Estructura

| Carpeta | Contenido |
|---|---|
| `app/` | App Flutter: app de campo Android (funciona sin internet) y verificador público (Flutter Web) |
| `backend/` | API Node.js + TypeScript (Fastify) para Cloud Run y worker de attestations |
| `schemas/` | Contratos compartidos por la API y la app: esquemas EAS (`schemas.json`), cultivos (`cultivos.json`) y vectores de prueba |
| `infra/` | Comandos de Google Cloud (Cloud SQL, Cloud Run, KMS, Firebase) |
| `docs/` | Plan y documentación |

## Requisitos

- Flutter 3.47+ (incluye Dart)
- Node.js 20+
- Google Cloud CLI (`gcloud`) y Firebase CLI (`firebase`)

## Comandos rápidos

```bash
# App Flutter
cd app && flutter pub get && flutter test

# Backend
cd backend && npm install && npm test

# Esquemas EAS (ver los strings sin registrar nada)
cd schemas && npm install && npm run register -- --dry-run

# Después de cambiar schemas/cultivos.json: regenerar la lista para la app
npm run cultivos-dart --workspace schemas
```

**CI:** GitHub Actions (`.github/workflows/ci.yml`) corre en cada push a `main` y en cada pull request: typecheck y pruebas de Node, `flutter analyze` y `flutter test`.

## Cultivos

Cada finca es de un cultivo (`cafe` o `cacao`). La configuración (nombre, código HS, estados de entrega y máximo de kg por entrega) está en `schemas/cultivos.json`. La API la lee directamente y la app la recibe como código generado (`app/lib/domain/cultivos_generados.dart`). Pruebas de contrato en ambos lados verifican que coincidan. Agregar un cultivo es, sobre todo, agregarlo a ese archivo y regenerar.

## Seguridad

Revisión del 23/10/2026 (API, Storage, rutas públicas, Hosting, keys y secretos): [`docs/revision-seguridad.md`](docs/revision-seguridad.md).

## Privacidad

En la blockchain solo se guardan hashes, IDs y resultados. Los datos personales de los productores (nombres, cédulas, polígonos exactos) se quedan en la base de datos. Esto cumple la Ley 787 de Protección de Datos Personales.

Cualquier productor o persona del equipo puede pedir que se borren sus datos en `/eliminar-datos` (página pública) o desde la app (⋮ → Privacidad y datos). Lo que el EUDR obliga a guardar se conserva 5 años sin datos personales. Ver [docs/plan-eliminacion-datos.md](docs/plan-eliminacion-datos.md).

## Licencia

MIT
