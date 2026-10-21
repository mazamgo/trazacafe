# Plan: eliminación de datos del productor, de la cuenta y de la cooperativa

> Aprobado el 21/10/2026. Es parte de la Fase 4 (Play Store) de [`plan-nicaragua-multicultivo.md`](plan-nicaragua-multicultivo.md).

## Contexto
- **Google Play** exige, a las apps con cuentas, una opción para eliminar la cuenta y sus datos **dentro de la app** y una **página web** donde pedirlo sin instalarla. La página nombra la app y al desarrollador y explica qué se borra, qué se conserva y por cuánto tiempo. Su enlace va en **Seguridad de los datos**.
- **La Ley 787** le da al **productor** (que no tiene cuenta) el derecho a pedir que borren sus datos.

## Decisiones
- **Productor:** lo pide en la página web y lo aprueba el **administrador de su cooperativa** (la responsable de los datos; GoProduction los procesa).
- **Datos ya exportados:** se **anonimizan** y se guardan **5 años** (EUDR, art. 12); después se borran solos.
- **Cooperativa:** se borra **todo, con 30 días de gracia** para cancelar y descargar; lo que el EUDR obliga a guardar se anonimiza.

## Estado

| Parte | Estado |
|---|---|
| Migración `013_eliminacion.sql` y reglas en `backend/src/eliminacion.ts` | Hecho; ensayada en Cloud SQL en una transacción revertida (38 comprobaciones) |
| API: solicitudes, productor, cuenta, organización, tarea diaria, CORS | Hecho; pruebas en `backend/test/eliminacion.test.ts` |
| La sincronización no revive lo eliminado (tabla `eliminados`) | Hecho |
| App: ⋮ → Privacidad y datos, solicitudes, eliminar productor, avisos, base local v7 | Hecho |
| Página web `/eliminar-datos` y `/privacidad` (borrador) | Hecho |
| Documentación: guía de uso, `app/README.md`, `infra/README.md` §4j, borrador de Seguridad de los datos | Hecho |
| Aplicar la migración 013, desplegar la API y Hosting, crear la tarea `eliminaciones` en Scheduler, nuevo APK | Hecho el 21/10/2026 (API `trazacafe-api-00017`; la tarea respondió 200 en su primera ejecución) |
| Prueba de punta a punta en el Samsung (abajo) | Pendiente |
| Revisar la política de privacidad y Seguridad de los datos con el abogado; correo de soporte (`SOPORTE_EMAIL`) | Pendiente |
| URL definitiva en Play Console (proyecto de producción o dominio propio) | Fase 4 |

## Verificación de punta a punta (después de desplegar)
1. Desde un navegador sin sesión, pedir la eliminación de un productor de prueba en `/eliminar-datos`.
2. Verla en el Samsung como administrador (aviso en Productores), buscar al productor y aprobarla.
3. Sincronizar y comprobar que desapareció del celular (o quedó como "Productor eliminado") y que sus fotos ya no están en Storage al día siguiente.
4. Abrir la página desde otro dispositivo, como la revisará Google.
