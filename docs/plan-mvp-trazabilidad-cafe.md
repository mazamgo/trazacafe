# Plan MVP: Trazabilidad de café nicaragüense en OP Mainnet (EAS)

## Contexto
Los exportadores de café en Nicaragua (Jinotega, Matagalpa, Nueva Segovia) deben demostrar a sus compradores europeos que su café cumple el **EUDR** (Reglamento UE 2023/1115, modificado por 2025/2650). Fechas de aplicación:
- **30 dic 2026:** operadores grandes y medianos.
- **30 jun 2027:** micro y pequeñas empresas.

El importador europeo necesita tres cosas por cada lote:
- La geolocalización de cada parcela: un punto si mide menos de 4 ha, un polígono si mide 4 ha o más.
- Una prueba de que no hubo deforestación después del 31/12/2020.
- Una prueba de que la producción fue legal.

Hoy muchas cooperativas manejan esto en Excel y papel. El MVP digitaliza la recolección de esos datos, encadena la custodia desde la finca hasta el contenedor y registra cada paso como *attestation* de **EAS en OP Mainnet**. Así el comprador puede comprobar que los datos no fueron alterados escaneando un QR.

**Honestidad sobre la blockchain:** el EUDR no exige usar blockchain. Lo que aporta es integridad verificable por terceros y una cadena de custodia auditable sin depender de nadie. Además, el proyecto califica para Retro Funding de Optimism. Lo que el cliente compra es el cumplimiento, y la blockchain es la garantía.

**Supuestos (ajustables):**
- Equipo de 1 a 2 desarrolladores con Flutter/Dart y algo de TypeScript para el backend.
- Cuenta de Google Play Console y Google Cloud ya activas.
- Hay acceso a una cooperativa piloto.
- Presupuesto inicial bajo, menos de US$2,000 más tiempo propio.

---

## 1. Qué incluye el MVP (y qué no)
**Incluye:**
1. **App de campo Android en Flutter (funciona sin internet):** el técnico registra al productor, la finca, el polígono o punto GPS y fotos. Sincroniza cuando hay señal.
2. **Chequeo de deforestación:** compara cada polígono con el mapa de cobertura forestal 2020 del JRC (la referencia de la UE) y con alertas de Global Forest Watch. Resultado: verde, amarillo o rojo.
3. **Cadena de custodia:** entrega en el beneficio húmedo → lote de pergamino → beneficio seco → lote de exportación o contenedor. Cada paso es una attestation que referencia a la anterior (`refUID`).
4. **Paquete EUDR:** exporta un GeoJSON compatible con la Declaración de Diligencia Debida (DDS) del sistema TRACES de la UE, más un PDF con el resumen por lote.
5. **Verificador público:** página `/v/{uid}` con QR para el saco o contenedor. Muestra el origen (mapa con ubicación aproximada), la cadena de pasos y enlaces a easscan.org.

**No incluye (fase 2):**
- Sensores IoT de secado y humedad con ESP32 (aquí encaja Nicarobótica).
- Mapeo con drones.
- Integración directa con la API de TRACES.
- Pagos a productores.

**Regla de privacidad:** en la blockchain solo van **hashes**, IDs y resultados. Los nombres, cédulas y polígonos exactos quedan fuera de la cadena, en la base de datos. Esto cumple la Ley 787 (Protección de Datos Personales) y requiere el consentimiento firmado del productor.

---

## 2. Arquitectura y software (Flutter + Google Cloud)

**Decisiones tomadas:**
- La app se hace en **Flutter**: Android primero, publicada en Google Play Console, más Flutter Web para el verificador.
- Todo se aloja en **Google Cloud**, con PostgreSQL + PostGIS.
- Play Console solo publica la app. La base de datos vive en Cloud SQL.

**Flujo:**
1. La app Flutter guarda los datos en SQLite en el celular.
2. Al tener señal, sincroniza con la API en **Cloud Run**.
3. La API guarda en **Cloud SQL (PostgreSQL + PostGIS)**.
4. Un worker agrupa los registros y firma las attestations con una clave guardada en **Cloud KMS**.
5. Las attestations se escriben en **EAS en OP Mainnet**.

| Capa | Herramienta | Por qué |
|---|---|---|
| App de campo (Android) | **Flutter 3 + Dart**, `drift` (SQLite offline), `geolocator` (GPS), `image_picker`/`camera`, `riverpod` (estado) | Una app que funciona sin internet en fincas sin señal |
| Mapas | `flutter_map` (OpenStreetMap) + `flutter_map_tile_caching` (mapas sin conexión), paquete `turf` (área y validar polígonos) | Gratis y sin conexión. Google Maps cobra por uso y funciona mal sin señal |
| QR / PDF | `qr_flutter`, `mobile_scanner` (leer QR), `pdf` + `printing` | Etiquetas de saco y reporte para el comprador |
| Verificador público | **Flutter Web** en **Firebase Hosting** (`/v/{uid}`) | Mismo código y modelos que la app |
| Login | **Firebase Authentication** (correo o teléfono), con el token verificado en el backend | Gratis en el MVP; se integra nativo con Flutter |
| API / backend | **Node.js + TypeScript** (Fastify) en **Cloud Run** | El SDK oficial de EAS es TypeScript; Cloud Run tiene capa gratuita y escala solo |
| Base de datos | **Cloud SQL for PostgreSQL + PostGIS** (instancia pequeña) | Postgres administrado; PostGIS cruza polígonos con capas forestales |
| Fotos y documentos | **Cloud Storage** | Se guarda el hash de cada archivo para la attestation |
| Tareas en lote | **Cloud Tasks / Cloud Scheduler** | Agrupa los registros y llama a `multiAttest` cada X minutos |
| Firma blockchain | **Cloud KMS** con clave **secp256k1** (la misma curva de Ethereum) + signer de viem para KMS de GCP | La clave privada nunca sale de Google; nadie la ve |
| Blockchain | **EAS** (ya viene instalado en OP Mainnet/Sepolia), `@ethereum-attestation-service/eas-sdk`, `viem` | No hace falta escribir contratos propios en el MVP |
| Contratos (opcional) | **Foundry**: un *Resolver* que solo acepta attestations de cooperativas registradas | Se agrega en la semana 4 si hace falta |
| Wallet de la cooperativa | **Safe** (multisig) como dueño o administrador; la clave en KMS firma en su nombre | El técnico nunca toca cripto |
| Red | **OP Sepolia** (pruebas) → **OP Mainnet** (piloto); RPC de Alchemy o QuickNode en plan gratuito | Gas de fracciones de centavo por attestation |
| Deforestación | **Global Forest Watch Data API** + capa **JRC GFC2020** cargada en PostGIS; **Google Earth Engine** si escala | Fuentes que reconoce la UE; Earth Engine es nativo de Google Cloud |
| Monitoreo | **Firebase Crashlytics** (app) + **Cloud Logging** (backend) | Incluidos en el ecosistema Google |
| Distribución | **Play Console**: pista de *prueba interna* para el piloto y producción después | Ya tienes la cuenta |
| Código abierto | **GitHub** (MIT): app, backend y `eudr-eas-schemas` (paquete npm + paquete Dart en pub.dev) | Requisito práctico para Retro Funding; el paquete Dart suma como herramienta para desarrolladores |

**Estructura del repo (monorepo):**
```
/app        → Flutter (Android + Web)
/backend    → Node/TS, API + worker de attestations (Cloud Run)
/schemas    → definición de esquemas EAS + scripts de registro
/infra      → scripts de gcloud / Terraform (Cloud SQL, Cloud Run, KMS)
/docs       → plan, guías de uso, documentación del SDK
```

**Esquemas EAS (borrador):**
- `Finca`: `fincaId`, `geoHash` (hash del polígono), `areaHa`, `deforestacionOK`, `fuenteChequeo`, `docsHash`
- `Entrega`: `fincaUID`, `kg`, `fecha`, `estado` (uva/pergamino)
- `Lote`: `entregasUIDs[]`, `kg`, `beneficio`, `proceso`
- `Exportacion`: `lotesUIDs[]`, `contenedor`, `destino`, `ddsRef`

Se usa `multiAttest` para firmar en lote y bajar costos. El atestador es la cooperativa, que firma con su Safe o su clave de servidor.

**Costo de infraestructura en el MVP:** aproximadamente US$15–40 al mes.
- Cloud SQL, instancia mínima: ~US$10–30.
- Cloud Run, Firebase Hosting, Firebase Auth (correo) y KMS: casi gratis a este volumen.
- La verificación por SMS sí cobra por mensaje.
- El gas de 10,000 attestations en OP Mainnet cuesta normalmente unos pocos dólares.
- Si tu cuenta de Google Cloud es nueva, aprovecha el crédito de prueba. Revisa también **Google for Startups Cloud Program**, que tiene créditos para startups, incluida una línea Web3.

---

## 3. Cronograma (8 semanas)

| Semana | Entregable |
|---|---|
| 0 (antes) | Validar el problema: 5 entrevistas con cooperativas o exportadores y 1–2 compradores de la UE. Preguntar qué les piden hoy y cuánto pagarían. Conseguir la carta de intención de 1 piloto. |
| 1 | Monorepo, proyecto en Google Cloud (Cloud SQL + PostGIS, Cloud Run, KMS, Firebase), modelo de datos, esquemas EAS registrados en OP Sepolia, diseño de pantallas |
| 2–3 | App Flutter offline (drift): productores, fincas, captura de polígonos con `flutter_map`, fotos, consentimiento; sincronización con la API de Cloud Run |
| 4 | Entregas → lotes → exportación; worker en Cloud Run firma con KMS y hace `multiAttest` en Sepolia |
| 5 | Chequeo de deforestación (PostGIS + GFW), exportación GeoJSON DDS y PDF |
| 6 | Verificador en Flutter Web (Firebase Hosting) + QR, panel de la cooperativa |
| 7 | Piloto real con 20–50 productores: app en la pista de **prueba interna de Play Console** y migración a OP Mainnet |
| 8 | Ajustes, documentación, publicar el SDK de esquemas, registro en **OP Atlas**, primer reporte de métricas |

**Métricas de éxito del MVP:**
- Al menos 30 fincas mapeadas.
- 1 lote de exportación completo, desde la finca hasta el contenedor.
- 1 comprador de la UE que acepte el paquete.
- Al menos 1 cliente que pague o firme una carta de intención.

---

## 4. Cómo cobrar
Los productores **nunca pagan**. Pagan quienes arriesgan perder el mercado europeo o ganan con la historia de origen.

| Cliente | Modelo | Precio hipotético (validar en la semana 0) |
|---|---|---|
| Cooperativa | Suscripción anual por productor registrado | US$2–5 por productor al año (mínimo ~US$50/mes) |
| Exportador | Cobro por **contenedor / paquete EUDR** generado | US$30–80 por contenedor |
| Tostador o comprador especial (UE/EE.UU.) | Acceso al verificador con su marca ("escanea y conoce a tu productor") | US$100–300/mes |
| Servicios | Mapeo de fincas en campo (técnicos con GPS, después con drones) y capacitación | Por finca o por jornada |

- Facturar en USD con contrato de servicio. Aceptar transferencia bancaria y, opcionalmente, USDC.
- Primeros 2 o 3 clientes: precio de fundador con descuento a cambio de testimonio y datos para métricas.

---

## 5. Retro Funding: qué es y cómo usarlo bien
**Cómo funciona:** Retro Funding paga **después** de que demuestras impacto, no antes. En la temporada 8 el presupuesto propuesto es ~5M OP, contra 16M en la temporada 7. Las misiones actuales son **Dev Tooling** y **Onchain Builders**, y miden métricas en la blockchain como transacciones, direcciones activas y gas, o la adopción por parte de otros desarrolladores. **No sirve para financiar el arranque.** Trátalo como un ingreso extra que llega después.

**Cómo calificar:**
1. Registrar el proyecto en **OP Atlas** (atlas.optimism.io) y vincular el repo de GitHub, los contratos o atestadores y las wallets.
2. **Onchain Builders:** cada finca, entrega y lote genera attestations reales en OP Mainnet con muchas cooperativas como atestadores, lo que suma actividad medible.
3. **Dev Tooling:** publicar `eudr-eas-schemas` (esquemas + SDK + documentación) para que otros proyectos lo reutilicen con cacao, ganado o madera, que también son productos del EUDR y que Nicaragua exporta.
4. Mantener todo como código abierto y documentado. Las métricas salen de Open Source Observer (OSO).

**Financiamiento inicial (antes del retro):**
- Grants Council de Optimism (subvenciones para builders de la Superchain).
- Programas de **Celo**, una L2 del OP Stack enfocada en mercados emergentes.
- Base Builder Grants.
- Gitcoin Grants.
- Programas de cooperación y comercio de la UE para preparar a productores ante el EUDR.

**Cómo usar los fondos si los recibes (sugerencia):**
- Convertir parte del OP a USDC al recibirlo para reducir la volatilidad, y registrarlo contablemente como ingreso.
- Distribución:
  - 40% desarrollo.
  - 25% piloto en campo (técnicos, GPS, transporte, capacitación).
  - 15% infraestructura y auditoría de seguridad.
  - 10% legal y contable.
  - 10% reserva.

**Verificar antes de aplicar:**
- La Optimism Foundation exige KYC/KYB y tiene restricciones por jurisdicción. Confirma en sus términos vigentes si residentes o empresas en Nicaragua pueden recibir fondos. Una alternativa es una entidad en otro país.
- Revisa las fechas exactas de cada temporada en gov.optimism.io.

---

## 6. Riesgos principales
- **Adopción:** las cooperativas pueden preferir Excel. Mitigación: un solo flujo simple, que el técnico de campo lo use desde el primer día y que genere el paquete EUDR "con un clic".
- **Regulación cambiante:** la Comisión Europea tenía pendiente una revisión de simplificación (abril 2026). Revisa su resultado, porque podría cambiar los requisitos.
- **Contexto local:** no se mueve dinero, así que el riesgo de ser considerado proveedor de activos virtuales (VASP) ante la UAF es bajo. Aun así, conviene validar con un abogado y cuidar los datos personales.
- **Competencia:** ya existen plataformas EUDR (SaaS europeos). La ventaja propia es estar en el terreno, usar español, trabajar sin internet, tener precio local y datos verificables públicamente.

---

## 7. Siguiente paso al aprobar
Guardar este plan como documento en `C:\Users\nicar\source\repos\Proyect OP\docs\plan-mvp-trazabilidad-cafe.md`. Luego, si lo deseas, crear la base del monorepo de la semana 1 en la misma carpeta:
- `app/`: proyecto Flutter con drift y flutter_map.
- `backend/`: Node/TS con Fastify y el SDK de EAS.
- `schemas/`: script para registrar los esquemas en OP Sepolia.
- `infra/`: comandos `gcloud` documentados.

Para lo anterior se necesitan Flutter SDK, Node 20+ y la CLI `gcloud` instalados. Lo verifico antes de empezar.

## Verificación
- **Del plan:** las fechas del EUDR y el estado de Retro Funding se revisaron con fuentes actuales (EC Access2Markets, gov.optimism.io).
- **Del MVP, al ejecutarlo:**
  - Registrar los esquemas en OP Sepolia y ver los UIDs en sepolia.optimism.easscan.org.
  - Ejecutar `flutter test`, y probar la app en modo avión: los registros deben quedar en cola y sincronizar al volver la señal.
  - Crear finca → entrega → lote → exportación en la app y comprobar que el verificador en Flutter Web muestra la cadena completa.
  - Confirmar que la dirección derivada de la clave KMS es la que aparece como atestador en easscan.
  - Validar el GeoJSON exportado contra la especificación de TRACES.
  - Hacer el piloto con datos reales antes de pasar a mainnet.
