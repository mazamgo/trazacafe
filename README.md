# TrazaCafé

Trazabilidad de café y cacao nicaragüenses para el reglamento europeo contra la deforestación (EUDR). Cada paso de la cadena de custodia (finca → entrega → lote → exportación) se registra como *attestation* de [EAS](https://attest.org) en OP Mainnet. El comprador lo verifica escaneando un QR.

Planes:
- [docs/plan-nicaragua-multicultivo.md](docs/plan-nicaragua-multicultivo.md): plan vigente (rentable en Nicaragua con café y cacao, después la región).
- [docs/plan-mvp-trazabilidad-cafe.md](docs/plan-mvp-trazabilidad-cafe.md): MVP original.

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

## Cultivos

Cada finca es de un cultivo (`cafe` o `cacao`). La configuración (nombre, código HS, estados de entrega y máximo de kg por entrega) está en `schemas/cultivos.json`. La API la lee directamente y la app la recibe como código generado (`app/lib/domain/cultivos_generados.dart`). Pruebas de contrato en ambos lados verifican que coincidan. Agregar un cultivo es, sobre todo, agregarlo a ese archivo y regenerar.

## Privacidad

En la blockchain solo se guardan hashes, IDs y resultados. Los datos personales de los productores (nombres, cédulas, polígonos exactos) se quedan en la base de datos. Esto cumple la Ley 787 de Protección de Datos Personales.

## Licencia

MIT
