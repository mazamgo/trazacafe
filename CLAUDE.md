# TrazaCafé: reglas para trabajar en este repo

- Responde y documenta en español.
- **La documentación se mantiene al día en el mismo commit que el cambio.** Si cambias algo, revisa y actualiza lo que corresponda:

  | Si cambias… | Actualiza |
  |---|---|
  | Pantallas, botones, flujos o mensajes de la app | `docs/guia-de-uso.md` (manual para técnicos y administradores) |
  | Variables de entorno de la API (`process.env.*`) | `backend/.env.example` |
  | Variables `--dart-define`, estructura de `app/`, versión de la base local o comandos de compilación | `app/README.md` |
  | Infraestructura, rutas de la API, migraciones, tareas programadas, despliegues | `infra/README.md` |
  | Avance de una fase o del plan | `docs/plan-nicaragua-multicultivo.md` |

- Pruebas: `npm test` en `backend/`; en `app/`, `tool\probar.ps1` (en Windows, archivo por archivo) y `flutter analyze`.
- Despliegues, migraciones, APK, commits y push: solo con aprobación explícita del usuario.
