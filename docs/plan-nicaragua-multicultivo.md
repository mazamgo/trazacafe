# Plan: TrazaCafé rentable en Nicaragua (café y cacao) y luego la región

> Planes anteriores: `docs/plan-mvp-trazabilidad-cafe.md` (MVP original). Lo de temporadas y visitas ya está hecho (commit 33c9641).

## Contexto
**Objetivo:** que el proyecto sea rentable, empezando solo en Nicaragua y con dos cultivos (café y cacao). Después, expandirse a otros países.

**Lo que se sabe del mercado:**
- Fairtrade ya regala el mapeo de parcelas a las cooperativas certificadas.
- osapiens, Koltiva y otras plataformas venden a importadores grandes.
- En Nicaragua no hay una plataforma dominante.
- El valor diferencial de TrazaCafé es la **cadena de custodia después del acopio** (finca → entrega → lote → contenedor), funcionar sin señal y en español, la verificación por temporada, la prueba pública en blockchain y el soporte local.

**Decisiones del usuario:**
- Cultivos: **café y cacao**.
- **Todavía no hay piloto** (hay que conseguirlo).
- La **empresa legal** entra como tarea del plan.

**Fechas que mandan:**
- 30/12/2026: el EUDR aplica a operadores grandes y medianos.
- Enero de 2027: Fairtrade exige el 100 % de la geolocalización de las cooperativas.
- Mediados de enero de 2027: termina la prueba gratis de Cloud SQL (empezó el 15/10/2026).
- 30/06/2027: el EUDR aplica a micro y pequeñas empresas.

## Lo que ya tenemos (hecho y en producción de pruebas)
- **App Android sin señal:** productores con foto del consentimiento, fincas con polígono validado (cruces, regla de 4 ha) y mapa satelital de Google, fotos subidas con hash verificado, entregas, temporadas, visita de verificación con historial del lindero y aviso al registrar entregas.
- **Acceso:** login con Google, acceso por invitación, roles de administrador y técnico, pantallas Equipo y Temporadas, y descarga de los datos del equipo.
- **API en Cloud Run** con Cloud SQL (PostGIS) por IAM, Storage con reglas por organización, área oficial calculada por PostGIS, chequeo satelital (GFW) con tarea diaria en Scheduler y API keys restringidas.
- **Esquemas EAS** (Finca con versión, Verificación, Entrega, Lote, Exportación), todavía sin registrar en la blockchain.

## Pendientes conocidos (se integran en las fases)
- Key de Global Forest Watch (cuenta con correo y contraseña; correo a gfw@wri.org enviado).
- Lotes, exportaciones, paquete EUDR, firma con Cloud KMS y attestations (era la semana 4).
- Riesgo de celular compartido entre organizaciones.
- Prueba de Equipo intermitente.
- Publicación en Play Store.
- Entorno de producción.
- Verificador web en Firebase Hosting.

---

## Fase 0 — Negocio y piloto (en paralelo a todo, desde ya)
1. **Conseguir 1 o 2 pilotos:**
   - Entrevistas a 6–8 organizaciones:
     - café en Jinotega, Matagalpa y Nueva Segovia;
     - cacao en Waslala, Matiguás y Río San Juan;
     - priorizar las **no certificadas Fairtrade** y las exportadoras privadas.
   - Demo con el APK actual.
   - Meta: **una carta de intención** con precio acordado y un contenedor de prueba antes de marzo de 2027.
2. **Validar precios** (hipótesis de partida):
   - US$2–4 por productor al año;
   - US$30–80 por contenedor;
   - mapeo de campo cobrado por finca.
   - Pedir 1 o 2 cotizaciones de competidores comerciales como referencia.
3. **Empresa legal (bloquea facturar, recibir fondos y publicar en Play Store como empresa):**
   - Elegir con un abogado entre GoProduction en Nicaragua o una entidad en Costa Rica, Panamá o EE.UU. (banca, KYC de Optimism y facturar a compradores de la UE).
   - Abrir cuenta para cobrar en USD.
4. **Documentos legales:**
   - Contrato de servicio con la organización.
   - Acuerdo de tratamiento de datos (Ley 787).
   - Política de privacidad y términos para Play Store.
   - Formato de consentimiento del productor (impreso, el que se fotografía en la app).
5. **Financiamiento complementario (no es la base del negocio):** Optimism Grants o Retro Funding (con el código abierto), Celo, BID Lab y programas de la UE de apoyo al EUDR.

## Fase 1 — Multicultivo: café y cacao (~3 semanas) — **hecha el 16/10/2026**
**Estado:**
- La migración 008 está aplicada en Cloud SQL, la API desplegada (revisión `trazacafe-api-00006`) y el APK probado en el Samsung con cacao activado.
- **Hecho después (API revisión `trazacafe-api-00007`):**
  - el cultivo siempre visible en Nueva finca;
  - «Cambiar cultivo» en fincas sin entregas.
- **Pendiente menor:** revisar en Cloud SQL una finca de cacao con entrega `fermentado` hecha desde el celular.

**Diseño:** el **cultivo es un dato de la finca**. Cada cultivo trae su configuración desde un archivo compartido entre la API y la app (como `test-vectors.json`), así que agregar otro cultivo es mayormente configuración.

- **Nuevo `schemas/cultivos.json`:**
  - `cafe`: estados `uva`, `pergamino`, `oro`; código HS 0901; máximo por entrega 20 t.
  - `cacao`: estados `baba`, `fermentado`, `seco`; código HS 1801; dos cosechas al año.
  - Los consumen `schemas/src/index.ts` (TypeScript) y un generador para Dart, igual que los vectores, con prueba de contrato en ambos lados.
- **Migración `008_cultivos.sql`:**
  - `organizaciones.cultivos text[]`;
  - `fincas.cultivo` (las fincas actuales quedan como `cafe`);
  - `temporadas.cultivo` opcional: vacío = todos los cultivos; permite cosechas de cacao separadas. La restricción de no traslape pasa a ser por organización **y cultivo**.
  - Las entregas toman el cultivo de su finca.
- **API** (`backend/src/sync.ts`, `repo.ts`):
  - valida que el `estado` de cada entrega exista para el cultivo de su finca;
  - `GET /v1/datos` devuelve el cultivo;
  - las temporadas se pueden crear por cultivo.
- **Esquemas EAS:** `Finca` y `Entrega` incluyen `cultivo` (aún no se registran, así que no hay costo).
- **App** (base local v5):
  - selector de cultivo en Nueva finca;
  - formulario de entrega con los estados del cultivo;
  - ícono y color por cultivo en las listas;
  - entregas agrupadas por temporada y cultivo;
  - la organización elige sus cultivos.
- **Decisión de marca:** se mantiene **TrazaCafé** para Nicaragua. Si el cacao pesa mucho en las ventas, evaluar un nombre más general antes de salir a otros países.

## Fase 2 — Del campo al contenedor: el paquete EUDR (~4 semanas, prioridad comercial)
Es la parte que **paga el cliente**.

**Avance:**
- **Lotes: hechos** (migración 009, pantalla Lotes para administradores). Detalle de reglas y avisos en `infra/README.md` §4f.
- Los factores de rendimiento por estado (`cultivos.json`) son aproximados y se validan con el piloto.
- **Contenedores: hechos** (migración 010, pantalla Contenedores). Detalle en `infra/README.md` §4g.
- **Paquete EUDR: hecho**: GeoJSON para TRACES, PDF para el comprador y cierre del contenedor (detalle en `infra/README.md` §4h).
  - Falta validar el GeoJSON en el entorno de aceptación de TRACES.
  - Ningún contenedor se puede cerrar mientras no haya chequeos satelitales en verde (key de GFW).
- **Attestations: código hecho**: firma con Cloud KMS, worker en cuatro olas, migración 011 y esquema `Chequeo` separado de `Finca`. Detalle en `infra/README.md` §3.
  - La clave HSM ya está creada (dirección `0xBFC2333a01536EdFDB3e6aB987c544CDeAC8CB99`).
  - Faltan: ETH de prueba, registrar los esquemas en OP Sepolia, aplicar la 011, desplegar y programar el worker.
- **Chequeo satelital propio: hecho.** Mapas públicos JRC GFC2020 V4 (bosque 2020, la referencia de la UE) y Hansen/UMD v1.12 (pérdida 2021-2024), leídos por partes. Ya no se depende de la key de GFW, que queda como complemento opcional para alertas recientes. Detalle en `infra/README.md` §4d.
- **Correcciones de datos: hechas** (migración 012). Se pueden corregir o anular entregas, lotes, productores, fincas, fotos, visitas y temporadas mientras no estén sellados, con historial y motivo. Detalle en `infra/README.md` §4i.
- **Período de gracia: hecho.** Entregas y visitas se firman a los 7 días de enviarlas, o antes si entran a un lote, para poder corregirlas sin revocar. La revocación de lo ya firmado sigue pendiente, para antes de OP Mainnet.
- **Verificador público: hecho.**
  - **Página:** `trazacafe-dev.web.app/v/{uid}` (Flutter Web), con la cadena del contenedor sin datos personales.
  - **Comprobación propia:** la página compara los datos con la attestation que lee directo de la blockchain.
  - **QR:** se genera en la app, en Contenedores y en Lotes (QR del saco).
  - **Idioma y tema:** la página está en español e inglés, con tema claro u oscuro. La app de campo también tiene tema claro u oscuro.
  - Detalle en `infra/README.md` §6.

- **Lotes** (beneficio o centro de acopio):
  - Agrupar entregas de un mismo cultivo y temporada.
  - **Control de volumen:** kg del lote frente a la suma de las entregas, y kg por finca frente a un rendimiento razonable por hectárea; si se excede, aviso.
  - **Reglas de exclusión:** no entran entregas de fincas en rojo ni de fincas sin visita en la temporada (lo que quedó preparado).
- **Exportaciones (contenedores):** agrupar lotes, con destino, comprador y número de contenedor.
- **Paquete EUDR:**
  - GeoJSON de **todas las fincas de origen** del contenedor en el formato de la DDS de TRACES;
  - PDF con el resumen para el comprador: fincas, áreas oficiales, estado satelital, visitas y attestations;
  - exportación compatible con Fairtrace y osapiens (CSV o GeoJSON) para cooperativas que ya los usan.
- **Attestations en la blockchain:**
  - clave secp256k1 en **Cloud KMS** (la clave nunca sale de Google);
  - registrar los esquemas en OP Sepolia y luego en OP Mainnet (`schemas/scripts/register.ts`);
  - worker en Cloud Run que procesa `attestations_pendientes` con `multiAttest` y encadena con `refUID` (versión de finca → visita → entrega → lote → exportación);
  - fondear la dirección con un poco de ETH en OP.
- **Verificador público** (Flutter Web en Firebase Hosting): QR del contenedor o del saco → cadena completa sin datos personales.

## Fase 3 — Panel web para administradores (~3 semanas)
- **Mismo código Flutter compilado para web,** con login de Google (la key de navegador ya está restringida por dominio).
- **Pantallas:** lotes, contenedores, paquete EUDR, alertas satelitales, avance de visitas por temporada, equipo y temporadas.
- **Reportes:** % de fincas verificadas, kg por cultivo y temporada, fincas en amarillo o rojo.

### Consola del propietario (GoProduction) (~2 semanas, cuando haya el primer cliente que paga)
Hoy GoProduction administra la plataforma a mano:
- crea organizaciones con `npm run crear-organizacion`;
- atiende las solicitudes de eliminación sin cooperativa con SQL;
- revisa las tareas en los logs de Google Cloud;
- no tiene cómo medir el uso para facturar.

Con 5 o 10 organizaciones eso no alcanza.

- **Dónde:**
  - **Web,** no en la app móvil: es trabajo de escritorio (tablas, filtros, exportar), y los permisos del dueño no deben viajar en una app que se descarga de Play Store.
  - **Mismo repositorio y mismo código Flutter Web** que el panel de esta fase, pero en un **sitio aparte de Firebase Hosting** (por ejemplo `consola-trazacafe.web.app`), separado de las páginas públicas (verificador, eliminación de datos).
- **API:**
  - rutas `/v1/consola/*` en la misma API, solo para el rol **propietario**: un custom claim que se asigna a mano a los correos de GoProduction con un script, nunca por invitación;
  - cuenta de Google con verificación en dos pasos;
  - cada acción queda en una tabla de historial de la consola.
- **Privacidad (Ley 787):** las cooperativas son responsables de los datos y GoProduction solo los procesa. La consola muestra **números por organización, no nombres ni cédulas**. Ver datos de una cooperativa para darle soporte solo con su permiso, y queda registrado.
- **Pantallas:**
  1. **Organizaciones:**
     - crear una con su primer administrador y sus cultivos (lo que hoy hace el script);
     - ver su plan;
     - suspenderla por falta de pago: la app y la API dejan de aceptar datos nuevos, pero la organización sigue viendo y descargando lo suyo;
     - ver si tiene una eliminación programada.
  2. **Uso y facturación,** por organización y por mes:
     - productores activos;
     - fincas y hectáreas;
     - contenedores con paquete EUDR;
     - fotos y espacio en Storage;
     - exportar a Excel para facturar (base de las métricas de la Fase 5).
  3. **Salud del sistema:**
     - última ejecución y resultado de cada tarea programada (attestations, chequeo satelital, eliminaciones);
     - attestations atascadas;
     - saldo de ETH de la clave de firma;
     - fincas en rojo por organización.
  4. **Solicitudes de eliminación:** las que no tienen cooperativa ("No sé") para asignarlas, y las que llevan más de 15 días sin respuesta (para escribirle a esa cooperativa).
  5. **Soporte:**
     - ver el equipo de una organización (correos y roles);
     - reenviar o cancelar una invitación;
     - nombrar a otro administrador si el único se fue.
- **Fuera de alcance al inicio:** cobro automático con tarjeta, y entrar como otro usuario ("ver como"). Se evalúan con 10 o más clientes.

## Fase 4 — Producción y lanzamiento en Nicaragua (~2–3 semanas, antes de que termine la prueba de Cloud SQL)
- **Proyecto `trazacafe-prod`** separado del de pruebas: Cloud SQL pagado con respaldos y recuperación a un punto en el tiempo, alertas de monitoreo y de presupuesto, keys propias y bucket propio.
- **Seguridad:**
  - Firebase App Check con Play Integrity en la API;
  - corregir el riesgo del celular compartido entre organizaciones;
  - revisión de seguridad (permisos, reglas de Storage, endpoints).
- **Play Store:**
  - clave de subida;
  - agregar el SHA-1 de Play App Signing a Firebase, a la key de Android y a la key de mapas (`--dart-define=ANDROID_CERT_SHA1`);
  - ficha en español y política de privacidad;
  - **eliminación de datos (requisito de Play): hecha en la app, la API y la página web** ([`docs/plan-eliminacion-datos.md`](plan-eliminacion-datos.md)). Falta revisar la política con el abogado, poner la URL definitiva en Play Console al pasar a producción y llenar Seguridad de los datos ([`docs/seguridad-de-datos-play.md`](seguridad-de-datos-play.md));
  - pruebas cerradas con el piloto.
- **Calidad:**
  - arreglar la prueba de Equipo intermitente;
  - CI en GitHub Actions con las pruebas de Node y Flutter (`app/tool/probar.ps1`).
- **Soporte:** guía de 1 página para técnicos, video corto, grupo de WhatsApp de soporte, y procedimiento de alta de una organización (`npm run crear-organizacion`).
- **Mapas sin señal:** revisar los términos de Google y, si no permiten guardar zonas, ofrecer la descarga de mapas base de otra fuente para zonas sin cobertura.

## Fase 5 — Rentabilidad en Nicaragua (desde el primer piloto)
**Paquetes (hipótesis a validar en la Fase 0):**

| Paquete | Para | Precio orientativo |
|---|---|---|
| Básico | Cooperativa de hasta 300 productores | US$2–4 por productor al año (mínimo ~US$50/mes) |
| Exportador | Exportadora o beneficio | Suscripción + US$30–80 por contenedor con paquete EUDR |
| Comprador | Importador o tostador de la UE | US$100–300/mes por el portal de sus proveedores |
| Servicios | Cualquiera | Mapeo de fincas en campo (con GPS y drones de Nicarobótica), capacitación, limpieza de datos |

**Costos estimados por mes:**
- Infraestructura de producción: US$80–200 (Cloud SQL de pago, Storage, Cloud Run y mapas por encima de la cuota gratis).
- El costo real es el equipo: 2–3 personas a tiempo parcial o completo en Nicaragua.

**Punto de equilibrio orientativo:** con unos US$5,000 al mes de gasto (equipo de 2–3 personas e infraestructura), se necesitan unos **US$60,000 al año**. Por ejemplo:
- 20 cooperativas × 400 productores × US$3 = US$24,000;
- 2–3 exportadoras con unos 200 contenedores × US$50 = US$10,000 + suscripción;
- servicios de mapeo y capacitación: US$15,000–25,000.

Son hipótesis; la Fase 0 las confirma o corrige.

**Métricas a seguir:**
- organizaciones que pagan y productores activos;
- contenedores con paquete EUDR;
- renovación por temporada;
- costo de incorporar cada organización.

## Fase 6 — Expansión (después de tener clientes que paguen en Nicaragua)
1. **Honduras y Guatemala** (café y cacao, español): configuración por país (cédula, documentos de tierra, requisitos de legalidad, ley de datos) y un socio local.
2. **Colombia, Perú y Ecuador:** capas oficiales de deforestación de cada país junto con GFW (IDEAM, Geobosques, SAC) y la interoperabilidad con los sistemas nacionales.
3. **Brasil:** portugués, integración con el CAR y PRODES/DETER.
4. **Ganado:** otro modelo de datos (animales, traslados, guías), con un socio del sector.

Lo que la Fase 1 ya deja preparado: cultivos configurables, organizaciones con varios cultivos y temporadas por cultivo.

---

## Calendario sugerido

| Período | Técnico | Negocio |
|---|---|---|
| Nov 2026 | Fase 1 (multicultivo) + key de GFW | Fase 0: entrevistas, demo, abogado |
| Nov–Dic 2026 | Fase 2 (lotes, contenedores, paquete EUDR, attestations) | Carta de intención del piloto |
| Ene 2027 | Fase 4 (producción, Play Store) antes de que termine la prueba de Cloud SQL | Contratos y entidad legal |
| Feb–Mar 2027 | Fase 3 (panel web) y consola del propietario (cuando pague el primer cliente) | Piloto con un contenedor real; primera factura |
| Abr–Jun 2027 | Ajustes con el piloto | 5–10 organizaciones antes del 30/06/2027 |
| 2º semestre 2027 | — | Decidir el primer país de expansión |

## Verificación por fase
- **Fase 1:**
  - pruebas de contrato del archivo de cultivos (TypeScript y Dart);
  - la migración 008 ensayada en una transacción revertida y luego aplicada;
  - una finca de cacao con entrega `fermentado` creada en el Samsung y revisada en Cloud SQL.
- **Fase 2:**
  - prueba de un contenedor completo de punta a punta en OP Sepolia: entregas → lote → contenedor → attestations encadenadas visibles en easscan;
  - el GeoJSON validado contra el formato de TRACES;
  - el PDF revisado con el piloto.
- **Fase 3:**
  - el panel probado con la cuenta de administrador y un técnico sin acceso al panel;
  - la consola del propietario rechaza (403) a administradores y técnicos de las cooperativas;
  - crear una organización desde la consola reemplaza al script;
  - la primera factura sale del reporte de uso.
- **Fase 4:**
  - la app instalada desde Play (pruebas cerradas) con login y mapas funcionando con el SHA-1 de Play;
  - App Check rechaza llamadas que no vienen de la app;
  - CI en verde.
- **Fase 5:** las métricas en el panel y la primera factura emitida.
