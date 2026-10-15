# TrazaCafé

Trazabilidad de café nicaragüense para el reglamento europeo contra la deforestación (EUDR). Cada paso de la cadena de custodia (finca → entrega → lote → exportación) se registra como *attestation* de [EAS](https://attest.org) en OP Mainnet. El comprador lo verifica escaneando un QR.

Plan completo: [docs/plan-mvp-trazabilidad-cafe.md](docs/plan-mvp-trazabilidad-cafe.md)

## Estructura

| Carpeta | Contenido |
|---|---|
| `app/` | App Flutter: app de campo Android (funciona sin internet) y verificador público (Flutter Web) |
| `backend/` | API Node.js + TypeScript (Fastify) para Cloud Run y worker de attestations |
| `schemas/` | Esquemas EAS (fuente única en `schemas.json`) y script para registrarlos |
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
```

## Privacidad

En la blockchain solo se guardan hashes, IDs y resultados. Los datos personales de los productores (nombres, cédulas, polígonos exactos) se quedan en la base de datos. Esto cumple la Ley 787 de Protección de Datos Personales.

## Licencia

MIT
