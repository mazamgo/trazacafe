# Seguridad de los datos (Google Play Console): borrador de respuestas

> **Borrador.** Revisarlo con el abogado junto con la política de privacidad (`/privacidad`) antes de publicar. Las respuestas deben coincidir con lo que hace la app; si algo cambia (por ejemplo, analítica o anuncios), hay que actualizarlas.

## Enlaces

| Pregunta de Play Console | Respuesta |
|---|---|
| Política de privacidad | `https://trazacafe-dev.web.app/privacidad` (en producción, la URL definitiva: Fase 4) |
| ¿La app permite crear cuentas? | Sí: inicio de sesión con Google, solo por invitación de la organización. |
| Enlace para pedir la eliminación de la cuenta y los datos | `https://trazacafe-dev.web.app/eliminar-datos` |
| Correo de soporte (también en la ficha de Play) | `mauricio.zambrana.g@gmail.com` (aparece en `/eliminar-datos` y `/privacidad`) |
| ¿Se puede pedir que se borren datos sin borrar la cuenta? | Sí: los productores (que no tienen cuenta) lo piden en la misma página; el administrador puede eliminar a un productor desde la app. |

## Prácticas generales

| Pregunta | Respuesta | Nota |
|---|---|---|
| ¿Los datos van cifrados en tránsito? | Sí | Todo por HTTPS (API en Cloud Run, Firebase). |
| ¿Se recogen o comparten datos? | Sí | |
| ¿Se venden datos o se usan para publicidad? | No | |

## Tipos de datos

| Categoría de Play | Dato en TrazaCafé | ¿Se recoge? | ¿Se comparte? | Para qué | ¿Opcional? |
|---|---|---|---|---|---|
| Información personal → Nombre | Nombre del productor; nombre de la cuenta de Google del equipo | Sí | No (*) | Funciones de la app (trazabilidad EUDR), gestión de la cuenta | No |
| Información personal → Correo electrónico | Correo del equipo (técnicos y administradores) | Sí | No | Gestión de la cuenta (invitación y acceso) | No |
| Información personal → ID de usuario | Identificador interno de Firebase | Sí | No | Gestión de la cuenta, seguridad | No |
| Información personal → Otra información | Cédula del productor (opcional) y comunidad | Sí | No (*) | Funciones de la app | Sí |
| Ubicación → Ubicación precisa | Puntos y polígonos de las fincas (GPS del celular al marcar el lindero) | Sí | No (*) | Funciones de la app (EUDR: geolocalización de cada finca) | No |
| Fotos y videos → Fotos | Consentimiento firmado del productor, fotos de fincas y de visitas | Sí | No | Funciones de la app (prueba de consentimiento y de la visita) | No |

(*) El comprador de un contenedor recibe la ubicación y el área de las fincas de origen (y el nombre del productor solo si la cooperativa lo incluye) en el paquete EUDR. Lo descarga y lo envía el administrador de la organización desde la app. Play no cuenta como "compartir" una transferencia que inicia el propio usuario; confirmarlo con el abogado.

No se recogen: contactos, mensajes, historial de navegación, datos de pago, salud, audio, archivos ajenos a la app, identificadores de publicidad ni analítica.

## Conservación y eliminación (lo que dice la página pública)

- **Cuenta del equipo:** se borra al pedirlo. Lo que registró la persona queda en su organización, sin su nombre ni su correo.
- **Productor:** se borran su nombre, cédula, comunidad y fotos, y las fincas no exportadas. Lo exportado se conserva **5 años** sin datos personales (EUDR, art. 12) y después se borra solo.
- **Organización:** se borra todo a los 30 días de pedirlo, salvo lo que el EUDR obliga a guardar.
- **Blockchain:** solo hay hashes y resultados, sin datos personales; no se pueden borrar.

Detalle técnico: [`infra/README.md` §4j](../infra/README.md#4j-eliminación-de-datos-google-play-y-ley-787).
