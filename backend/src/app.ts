import Fastify, { type FastifyReply, type FastifyRequest } from "fastify";
import { z } from "zod";
import { rutaFoto, sha256Hex, type Almacen } from "./almacen.ts";
import { estaActivo, type Identidad, type Usuario, type UsuarioActivo, type VerificarToken } from "./auth.ts";
import { procesarCola, type ColaAttestations, type RedEAS } from "./atestador.ts";
import {
  anulacionSchema,
  correccionEntregaSchema,
  correccionFincaSchema,
  correccionLoteSchema,
  correccionProductorSchema,
  correccionTemporadaSchema,
  correccionVisitaSchema,
  type Correcciones,
  type Resultado,
} from "./correcciones.ts";
import { revisar, type FuenteSatelital } from "./deforestacion.ts";
import {
  aprobarSolicitudSchema,
  eliminarProductorSchema,
  rechazarSolicitudSchema,
  solicitudProductorSchema,
  type Eliminaciones,
} from "./eliminacion.ts";
import { cambiosExportacionSchema, evaluarExportacion, exportacionSchema } from "./exportaciones.ts";
import { evaluarLote, loteSchema, motivoExclusion } from "./lotes.ts";
import { geojsonTraces, motivosNoCierre, pdfPaquete } from "./paquete.ts";
import { AccesoDenegado, DatosInvalidos, VersionDesfasada, type Repo } from "./repo.ts";
import { cambioCultivoSchema, cultivosOrganizacionSchema, syncSchema, temporadaSchema } from "./sync.ts";
import { UID_VALIDO, type Verificador } from "./verificador.ts";

const invitacionSchema = z.object({
  email: z.email().transform((e) => e.toLowerCase()),
  rol: z.enum(["admin", "tecnico"]),
});

/** Fincas que revisa cada ejecución diaria de la tarea programada. */
const FINCAS_POR_TAREA = 50;

/** Solicitudes de eliminación que acepta la página pública por IP y por hora. */
const SOLICITUDES_POR_HORA = 5;
/** Archivos de Storage que borra cada ejecución de la tarea de eliminaciones. */
const ARCHIVOS_POR_TAREA = 500;

/**
 * Rutas que llama la página web pública (eliminar-datos) desde otro dominio.
 * CORS abierto: la sesión va en el encabezado Authorization, no en cookies.
 */
const RUTAS_WEB = [
  "/v1/publico/organizaciones",
  "/v1/publico/solicitudes-eliminacion",
  "/v1/cuenta",
  "/v1/organizacion",
  "/v1/organizacion/eliminacion",
];

/** Valida el token OIDC con el que Cloud Scheduler llama a las tareas. */
export type VerificarTarea = (token: string) => Promise<boolean>;

export function buildApp({
  repo,
  verificarToken,
  identidad,
  almacen,
  satelite,
  verificarTarea,
  atestador = null,
  correcciones = null,
  verificador = null,
  eliminaciones = null,
}: {
  repo: Repo;
  verificarToken: VerificarToken;
  identidad: Identidad;
  almacen: Almacen;
  /** `null` mientras no haya API key de Global Forest Watch. */
  satelite: FuenteSatelital | null;
  verificarTarea: VerificarTarea;
  /** `null` mientras no haya clave de firma en Cloud KMS. */
  atestador?: { cola: ColaAttestations; red: RedEAS } | null;
  /** Corregir y anular datos con errores (CorreccionesPg). */
  correcciones?: Correcciones | null;
  /** Cadena pública de un contenedor o lote firmado (VerificadorPg). */
  verificador?: Verificador | null;
  /** Eliminación de productores, cuentas y organizaciones (EliminacionesPg). */
  eliminaciones?: Eliminaciones | null;
}) {
  // trustProxy: solo se confía en el primer salto (el frontal de Cloud Run),
  // que agrega la IP real al final de X-Forwarded-For. Con `true` se tomaría la
  // primera, que la pone quien hace la petición (se saltaría el límite por IP).
  const app = Fastify({ logger: process.env.NODE_ENV !== "test", trustProxy: (_ip, salto) => salto === 0 });

  // Un error interno no muestra su mensaje (podría traer SQL, nombres de
  // tablas o datos): se registra en el log y se responde uno genérico.
  app.setErrorHandler((err: { statusCode?: number; code?: string; message: string }, req, reply) => {
    const status = err.statusCode && err.statusCode >= 400 && err.statusCode < 500 ? err.statusCode : 500;
    if (status === 500) {
      req.log.error({ err }, "error interno");
      return reply.code(500).send({
        error: "error_interno",
        mensaje: "Ocurrió un error en el servidor. Intenta de nuevo; si sigue, avisa a soporte.",
      });
    }
    return reply.code(status).send({ error: err.code ?? "solicitud_invalida", mensaje: err.message });
  });

  app.addHook("onRequest", async (req, reply) => {
    if (RUTAS_WEB.includes(req.url.split("?")[0])) {
      reply.header("access-control-allow-origin", "*");
      reply.header("access-control-allow-headers", "authorization, content-type");
      reply.header("access-control-allow-methods", "GET, POST, DELETE, OPTIONS");
    }
  });
  for (const ruta of RUTAS_WEB) app.options(ruta, async (_req, reply) => reply.code(204).send());

  async function autenticar(req: FastifyRequest, reply: FastifyReply): Promise<Usuario | null> {
    const token = req.headers.authorization?.replace(/^Bearer /, "");
    const usuario = token ? await verificarToken(token) : null;
    if (!usuario) reply.code(401).send({ error: "No autenticado" });
    return usuario;
  }

  /** Exige una invitación ya activada; con `soloAdmin`, además rol admin. */
  async function activo(req: FastifyRequest, reply: FastifyReply, soloAdmin = false): Promise<UsuarioActivo | null> {
    const usuario = await autenticar(req, reply);
    if (!usuario) return null;
    if (!estaActivo(usuario)) {
      reply.code(403).send({ error: "sin_acceso", mensaje: "Tu cuenta no tiene acceso a ninguna organización." });
      return null;
    }
    if (soloAdmin && usuario.rol !== "admin") {
      reply.code(403).send({ error: "solo_admin", mensaje: "Solo un administrador puede hacer esto." });
      return null;
    }
    return usuario;
  }

  app.get("/health", async () => ({ ok: true }));

  /**
   * Verificador público (QR del contenedor o del lote): sin sesión y desde
   * cualquier página, porque lo abre el comprador. Solo lo firmado y nada
   * personal (`verificador.ts`).
   */
  app.get<{ Params: { uid: string } }>("/v1/publico/:uid", async (req, reply) => {
    reply.header("access-control-allow-origin", "*");
    if (!UID_VALIDO.test(req.params.uid)) {
      return reply.code(400).send({ error: "uid_invalido", mensaje: "El código no es válido." });
    }
    if (!verificador) return reply.code(503).send({ error: "sin_verificador" });
    const cadena = await verificador.cadena(req.params.uid);
    if (!cadena) {
      return reply.code(404).send({
        error: "no_encontrado",
        mensaje: "Este código no corresponde a ningún contenedor ni lote registrado en la blockchain.",
      });
    }
    reply.header("cache-control", "public, max-age=300");
    return cadena;
  });

  /** Sin eliminaciones configuradas (pruebas), las rutas responden 503. */
  function sinEliminaciones(reply: FastifyReply): boolean {
    if (eliminaciones) return false;
    reply.code(503).send({ error: "sin_eliminaciones" });
    return true;
  }

  /** Responde el error de [r]; `true` si salió bien. */
  function salioBien<T>(reply: FastifyReply, r: Resultado<T>): r is Extract<Resultado<T>, { ok: true }> {
    if (r.ok) return true;
    reply.code(r.status).send({ error: "no_eliminable", mensaje: r.mensaje });
    return false;
  }

  /** Cooperativas que puede elegir un productor en la página de eliminación (solo nombres). */
  app.get("/v1/publico/organizaciones", async (_req, reply) => {
    if (sinEliminaciones(reply)) return;
    reply.header("cache-control", "public, max-age=300");
    return { organizaciones: await eliminaciones!.organizacionesPublicas() };
  });

  const solicitudesPorIp = new Map<string, number[]>();
  /**
   * Un productor pide que borren sus datos (página web, sin sesión). La
   * aprueba el administrador de su cooperativa en la app.
   */
  app.post("/v1/publico/solicitudes-eliminacion", async (req, reply) => {
    if (sinEliminaciones(reply)) return;
    const ahora = Date.now();
    // Que la memoria no crezca sin límite con IPs que ya no envían nada.
    if (solicitudesPorIp.size > 10_000) {
      for (const [ip, tiempos] of solicitudesPorIp) {
        if (tiempos.every((t) => ahora - t >= 3600_000)) solicitudesPorIp.delete(ip);
      }
    }
    const recientes = (solicitudesPorIp.get(req.ip) ?? []).filter((t) => ahora - t < 3600_000);
    if (recientes.length >= SOLICITUDES_POR_HORA) {
      return reply.code(429).send({ error: "demasiadas", mensaje: "Ya enviaste varias solicitudes. Intenta de nuevo en una hora." });
    }
    const datos = solicitudProductorSchema.safeParse(req.body);
    if (!datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", mensaje: datos.error.issues[0]?.message, detalles: datos.error.issues });
    }
    solicitudesPorIp.set(req.ip, [...recientes, ahora]);
    // Un bot llenó el campo escondido: se le responde igual, sin guardar nada.
    if (datos.data.sitio) return reply.code(201).send({ recibida: true });
    if (!(await eliminaciones!.crearSolicitud(datos.data))) {
      return reply.code(422).send({ error: "organizacion_desconocida", mensaje: "Elige tu cooperativa de la lista." });
    }
    return reply.code(201).send({ recibida: true });
  });

  /**
   * Eliminar la propia cuenta (app o página web): quita el acceso, borra la
   * invitación y la cuenta de Firebase. Lo que la persona registró se queda
   * en la organización (es de ella); solo guarda su uid como autor.
   */
  app.delete("/v1/cuenta", async (req, reply) => {
    const usuario = await autenticar(req, reply);
    if (!usuario || sinEliminaciones(reply)) return;
    const r = await eliminaciones!.eliminarCuenta(usuario);
    if (!salioBien(reply, r)) return;
    await identidad.quitarAcceso(usuario.uid);
    await identidad.eliminarUsuario(usuario.uid);
    return reply.code(204).send();
  });

  app.get("/v1/solicitudes-eliminacion", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin || sinEliminaciones(reply)) return;
    return { solicitudes: await eliminaciones!.solicitudesPendientes(admin.organizacionId) };
  });

  app.post<{ Params: { id: string } }>("/v1/solicitudes-eliminacion/:id/aprobar", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin || sinEliminaciones(reply)) return;
    const datos = aprobarSolicitudSchema.safeParse(req.body);
    if (!z.uuid().safeParse(req.params.id).success || !datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", mensaje: "Elige el productor que corresponde a la solicitud." });
    }
    const r = await eliminaciones!.aprobarSolicitud(admin, req.params.id, datos.data.productorId);
    return salioBien(reply, r) ? r.valor : undefined;
  });

  app.post<{ Params: { id: string } }>("/v1/solicitudes-eliminacion/:id/rechazar", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin || sinEliminaciones(reply)) return;
    const datos = rechazarSolicitudSchema.safeParse(req.body);
    if (!z.uuid().safeParse(req.params.id).success || !datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", mensaje: datos.error?.issues[0]?.message ?? "No encontrada." });
    }
    const r = await eliminaciones!.rechazarSolicitud(admin, req.params.id, datos.data.motivo);
    return salioBien(reply, r) ? reply.code(204).send() : undefined;
  });

  /** El administrador elimina los datos de un productor que lo pidió en persona. */
  app.delete<{ Params: { id: string } }>("/v1/productores/:id", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin || sinEliminaciones(reply)) return;
    if (!z.uuid().safeParse(req.params.id).success) return reply.code(404).send({ error: "no_encontrado" });
    const datos = eliminarProductorSchema.safeParse(req.body ?? {});
    if (!datos.success) return reply.code(422).send({ error: "Datos inválidos", mensaje: datos.error.issues[0]?.message });
    const r = await eliminaciones!.eliminarProductor(admin, req.params.id, datos.data.motivo ?? null);
    return salioBien(reply, r) ? r.valor : undefined;
  });

  /** Programa la eliminación de toda la organización (se ejecuta en 30 días). */
  app.post("/v1/organizacion/eliminacion", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin || sinEliminaciones(reply)) return;
    const r = await eliminaciones!.programarEliminacionOrganizacion(admin);
    return salioBien(reply, r) ? { eliminacionProgramada: r.valor } : undefined;
  });

  app.delete("/v1/organizacion/eliminacion", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin || sinEliminaciones(reply)) return;
    const r = await eliminaciones!.cancelarEliminacionOrganizacion(admin);
    return salioBien(reply, r) ? reply.code(204).send() : undefined;
  });

  /**
   * Tarea diaria (Cloud Scheduler): ejecuta las eliminaciones de
   * organizaciones que cumplieron 30 días, borra lo anonimizado cuyo plazo
   * EUDR venció y los archivos de Storage pendientes.
   */
  app.post("/v1/tareas/eliminaciones", async (req, reply) => {
    const token = req.headers.authorization?.replace(/^Bearer /, "");
    if (!token || !(await verificarTarea(token))) return reply.code(401).send({ error: "No autorizado" });
    if (sinEliminaciones(reply)) return;
    const r = await eliminaciones!.tareaDiaria();
    let cuentasBorradas = 0;
    for (const org of r.organizaciones) {
      for (const uid of org.usuarios) {
        try {
          await identidad.quitarAcceso(uid);
          await identidad.eliminarUsuario(uid);
          cuentasBorradas++;
        } catch (e) {
          req.log.error({ uid, err: e }, "eliminaciones: no se pudo borrar una cuenta");
        }
      }
    }
    const rutas = await eliminaciones!.archivosPorBorrar(ARCHIVOS_POR_TAREA);
    const resultados = await Promise.allSettled(rutas.map((ruta) => almacen.borrar(ruta)));
    const borrados = rutas.filter((_, i) => resultados[i].status === "fulfilled");
    await eliminaciones!.archivosBorrados(borrados, rutas.filter((_, i) => resultados[i].status === "rejected"));
    if (r.solicitudesSinRespuesta > 0) {
      req.log.warn({ solicitudes: r.solicitudesSinRespuesta }, "eliminaciones: solicitudes de productores sin respuesta");
    }
    return {
      organizaciones: r.organizaciones.length,
      cuentasBorradas,
      fincasPurgadas: r.fincasPurgadas,
      archivosBorrados: borrados.length,
      solicitudesSinRespuesta: r.solicitudesSinRespuesta,
    };
  });

  /**
   * Primer inicio de sesión: si el correo de Google tiene invitación, guarda
   * organización y rol en el token. La app debe refrescar el token después.
   */
  app.post("/v1/activar", async (req, reply) => {
    const usuario = await autenticar(req, reply);
    if (!usuario) return;
    if (estaActivo(usuario)) return { organizacionId: usuario.organizacionId, rol: usuario.rol };

    const inv = await repo.buscarInvitacion(usuario.email);
    if (!inv) {
      return reply.code(403).send({
        error: "sin_invitacion",
        mensaje: "Tu cuenta no está autorizada. Pide acceso al administrador de tu organización.",
      });
    }
    if (inv.usuarioUid && inv.usuarioUid !== usuario.uid) {
      return reply.code(409).send({ error: "invitacion_usada", mensaje: "Esta invitación ya la usó otra cuenta." });
    }
    await identidad.asignarAcceso(usuario.uid, { organizacionId: inv.organizacionId, rol: inv.rol });
    await repo.aceptarInvitacion(inv.email, usuario.uid);
    return { organizacionId: inv.organizacionId, rol: inv.rol };
  });

  app.post("/v1/sync", async (req, reply) => {
    const usuario = await activo(req, reply);
    if (!usuario) return;

    const datos = syncSchema.safeParse(req.body);
    if (!datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", detalles: datos.error.issues });
    }
    try {
      await repo.guardarSync(usuario, datos.data);
    } catch (e) {
      if (e instanceof AccesoDenegado) return reply.code(403).send({ error: e.message });
      if (e instanceof DatosInvalidos) return reply.code(422).send({ error: "datos_invalidos", mensaje: e.message });
      if (e instanceof VersionDesfasada) {
        return reply.code(409).send({ error: "version_desfasada", mensaje: e.message });
      }
      throw e;
    }
    const d = datos.data;
    return {
      recibidos: {
        productores: d.productores.length,
        fincas: d.fincas.length,
        versionesFinca: d.versionesFinca.length,
        verificaciones: d.verificaciones.length,
        entregas: d.entregas.length,
        fotos: d.fotos.length,
      },
    };
  });

  app.get("/v1/organizacion", async (req, reply) => {
    const usuario = await activo(req, reply);
    if (!usuario) return;
    return repo.organizacion(usuario.organizacionId);
  });

  /** Solo administradores: con qué cultivos trabaja la organización. */
  app.put("/v1/organizacion/cultivos", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    const datos = cultivosOrganizacionSchema.safeParse(req.body);
    if (!datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", detalles: datos.error.issues });
    }
    const conFincas = await repo.actualizarCultivos(admin.organizacionId, [...new Set(datos.data.cultivos)]);
    if (conFincas.length > 0) {
      return reply.code(409).send({
        error: "cultivo_con_fincas",
        mensaje: `No se puede quitar ${conFincas.join(", ")}: ya tiene fincas registradas.`,
      });
    }
    return repo.organizacion(admin.organizacionId);
  });

  app.get("/v1/temporadas", async (req, reply) => {
    const usuario = await activo(req, reply);
    if (!usuario) return;
    return { temporadas: await repo.listarTemporadas(usuario.organizacionId) };
  });

  app.post("/v1/temporadas", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    const datos = temporadaSchema.safeParse(req.body);
    if (!datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", detalles: datos.error.issues });
    }
    const cultivos = (await repo.organizacion(admin.organizacionId))?.cultivos ?? [];
    if (datos.data.cultivo && !cultivos.includes(datos.data.cultivo)) {
      return reply.code(422).send({
        error: "datos_invalidos",
        mensaje: `La organización no trabaja ${datos.data.cultivo}; actívelo primero en Cultivos.`,
      });
    }
    const t = await repo.crearTemporada(admin.organizacionId, { ...datos.data, id: crypto.randomUUID() }, admin.uid);
    if (!t) {
      return reply.code(409).send({ error: "traslape", mensaje: "Esas fechas se cruzan con otra temporada." });
    }
    return reply.code(201).send(t);
  });

  /**
   * Chequeo satelital programado (Cloud Scheduler, una vez al día). Revisa
   * las fincas que todavía no tienen chequeo de su lindero vigente en la
   * temporada actual: en la práctica, una vez por temporada.
   */
  app.post("/v1/tareas/chequeo-deforestacion", async (req, reply) => {
    const token = req.headers.authorization?.replace(/^Bearer /, "");
    if (!token || !(await verificarTarea(token))) return reply.code(401).send({ error: "No autorizado" });
    if (!satelite) return reply.code(503).send({ error: "sin_satelite", mensaje: "Falta GFW_API_KEY." });

    const fincas = await repo.fincasPorRevisar(FINCAS_POR_TAREA);
    const resultados = { revisadas: 0, verde: 0, amarillo: 0, rojo: 0, errores: 0 };
    for (const f of fincas) {
      try {
        const c = await revisar(satelite, f);
        await repo.guardarChequeo(c);
        resultados.revisadas++;
        resultados[c.resultado]++;
      } catch (e) {
        resultados.errores++;
        req.log.error({ fincaId: f.fincaId, err: e }, "chequeo satelital falló");
      }
    }
    return resultados;
  });

  /**
   * Firma en la blockchain lo que está en cola (Cloud Scheduler, cada hora):
   * fincas, chequeos, visitas, entregas, lotes y contenedores, en ese orden.
   */
  app.post("/v1/tareas/attestations", async (req, reply) => {
    const token = req.headers.authorization?.replace(/^Bearer /, "");
    if (!token || !(await verificarTarea(token))) return reply.code(401).send({ error: "No autorizado" });
    if (!atestador) return reply.code(503).send({ error: "sin_atestador", mensaje: "Falta KMS_KEY_VERSION." });
    const resumen = await procesarCola(atestador.cola, atestador.red);
    if (resumen.error) req.log.error({ error: resumen.error }, "attestations: falló una ola");
    return resumen;
  });

  /** Revisar una finca ahora (p. ej. después de una denuncia). Solo administradores. */
  app.post<{ Params: { id: string } }>("/v1/fincas/:id/chequeo", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    if (!satelite) return reply.code(503).send({ error: "sin_satelite", mensaje: "El chequeo satelital aún no está configurado." });
    if (!z.uuid().safeParse(req.params.id).success) return reply.code(404).send({ error: "no_encontrada" });

    const finca = await repo.fincaParaRevisar(admin.organizacionId, req.params.id);
    if (!finca) return reply.code(404).send({ error: "no_encontrada" });
    const c = await revisar(satelite, finca);
    await repo.guardarChequeo(c);
    return { resultado: c.resultado, alertas: c.alertas, areaAfectadaHa: c.areaAfectadaHa };
  });

  /** Productores, fincas y entregas de toda la organización (lo de todo el equipo). */
  app.get("/v1/datos", async (req, reply) => {
    const usuario = await activo(req, reply);
    if (!usuario) return;
    const datos = await repo.datosOrganizacion(usuario.organizacionId);
    const solicitudesPendientes =
      usuario.rol === "admin" && eliminaciones ? await eliminaciones.contarPendientes(usuario.organizacionId) : 0;
    return { ...datos, solicitudesPendientes };
  });

  /**
   * La app avisa que ya subió el archivo de una foto a Storage. La API lo lee
   * y solo lo acepta si su SHA-256 es el que llegó al sincronizar: así el
   * hash que irá en la attestation corresponde de verdad a la foto guardada.
   */
  app.post<{ Params: { id: string } }>("/v1/fotos/:id/subida", async (req, reply) => {
    const usuario = await activo(req, reply);
    if (!usuario) return;
    if (!z.uuid().safeParse(req.params.id).success) return reply.code(404).send({ error: "no_encontrada" });

    const foto = await repo.buscarFoto(usuario.organizacionId, req.params.id);
    if (!foto) return reply.code(404).send({ error: "no_encontrada", mensaje: "Sincroniza la foto antes de subirla." });

    const ruta = rutaFoto(usuario.organizacionId, req.params.id);
    if (foto.storagePath === ruta) return { storagePath: ruta };

    const archivo = await almacen.leer(ruta);
    if (!archivo) return reply.code(409).send({ error: "sin_archivo", mensaje: "El archivo todavía no está en Storage." });
    if (sha256Hex(archivo) !== foto.sha256) {
      await almacen.borrar(ruta);
      return reply.code(422).send({
        error: "hash_distinto",
        mensaje: "El archivo subido no coincide con la foto registrada; se borró. Vuelve a subirla.",
      });
    }
    await repo.marcarFotoSubida(req.params.id, ruta);
    return { storagePath: ruta };
  });

  /** Corrige un error de campo: borra una finca que aún no se atestó. */
  app.delete<{ Params: { id: string } }>("/v1/fincas/:id", async (req, reply) => {
    const usuario = await activo(req, reply);
    if (!usuario) return;
    if (!z.uuid().safeParse(req.params.id).success) return reply.code(404).send({ error: "no_encontrada" });

    const r = await repo.eliminarFinca(usuario.organizacionId, req.params.id);
    if (r.estado === "no_encontrada") return reply.code(404).send({ error: "no_encontrada" });
    if (r.estado === "atestada") {
      return reply.code(409).send({
        error: "atestada",
        mensaje: "Esta finca o una de sus entregas ya está en la blockchain; hay que revocar su attestation.",
      });
    }
    if (r.estado === "en_lote") {
      return reply.code(409).send({
        error: "en_lote",
        mensaje: "Una entrega de esta finca ya está en un lote; primero deshaz el lote.",
      });
    }
    // Si falla borrar un archivo, la finca ya no existe: queda un archivo
    // huérfano en Storage, que no expone nada (solo lo lee la organización).
    await Promise.allSettled(r.archivos.map((a) => almacen.borrar(a)));
    return reply.code(204).send();
  });

  /** Cambia el cultivo de una finca mientras no tenga entregas. */
  app.put<{ Params: { id: string } }>("/v1/fincas/:id/cultivo", async (req, reply) => {
    const usuario = await activo(req, reply);
    if (!usuario) return;
    if (!z.uuid().safeParse(req.params.id).success) return reply.code(404).send({ error: "no_encontrada" });
    const datos = cambioCultivoSchema.safeParse(req.body);
    if (!datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", detalles: datos.error.issues });
    }
    const org = await repo.organizacion(usuario.organizacionId);
    if (!org?.cultivos.includes(datos.data.cultivo)) {
      return reply.code(422).send({
        error: "datos_invalidos",
        mensaje: `La organización no trabaja ${datos.data.cultivo}; actívelo primero en Cultivos.`,
      });
    }
    const r = await repo.cambiarCultivoFinca(usuario.organizacionId, req.params.id, datos.data.cultivo);
    if (r === "no_encontrada") return reply.code(404).send({ error: "no_encontrada" });
    if (r === "con_entregas") {
      return reply.code(409).send({
        error: "con_entregas",
        mensaje: "La finca ya tiene entregas registradas con los estados de su cultivo; no se puede cambiar.",
      });
    }
    if (r === "atestada") {
      return reply.code(409).send({ error: "atestada", mensaje: "La finca ya está en la blockchain; no se puede cambiar su cultivo." });
    }
    return { cultivo: datos.data.cultivo };
  });

  /** Lotes del beneficio o centro de acopio (solo administradores). */
  app.get("/v1/lotes", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    return { lotes: await repo.listarLotes(admin.organizacionId) };
  });

  /** Entregas de un cultivo y temporada, con el motivo si no pueden ir a un lote. */
  app.get<{ Querystring: { cultivo?: string; temporadaId?: string } }>("/v1/lotes/disponibles", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    const q = z.object({ cultivo: z.string().regex(/^[a-z_]+$/), temporadaId: z.uuid() }).safeParse(req.query);
    if (!q.success) return reply.code(422).send({ error: "Datos inválidos", detalles: q.error.issues });
    const entregas = await repo.entregasCandidatas(admin.organizacionId, q.data);
    return {
      entregas: entregas.map((e) => ({ ...e, motivo: motivoExclusion(e, q.data.cultivo, q.data.temporadaId) })),
    };
  });

  app.post("/v1/lotes", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    const datos = loteSchema.safeParse(req.body);
    if (!datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", detalles: datos.error.issues });
    }
    const l = datos.data;
    const org = await repo.organizacion(admin.organizacionId);
    if (!org?.cultivos.includes(l.cultivo)) {
      return reply.code(422).send({ error: "datos_invalidos", mensaje: `La organización no trabaja ${l.cultivo}.` });
    }
    const temporada = (await repo.listarTemporadas(admin.organizacionId)).find((t) => t.id === l.temporadaId);
    if (!temporada || (temporada.cultivo !== null && temporada.cultivo !== l.cultivo)) {
      return reply.code(422).send({ error: "datos_invalidos", mensaje: "Esa temporada no es de este cultivo." });
    }

    const candidatas = await repo.entregasCandidatas(admin.organizacionId, { ids: l.entregas });
    const { rechazos, avisos, kgEsperados } = evaluarLote(l, candidatas);
    if (rechazos.length > 0) {
      return reply.code(422).send({
        error: "entregas_excluidas",
        mensaje: `${rechazos.length} ${rechazos.length === 1 ? "entrega no puede" : "entregas no pueden"} ir en el lote: ${rechazos[0].motivo}.`,
        rechazos,
      });
    }
    const id = crypto.randomUUID();
    const r = await repo.guardarLote(admin.organizacionId, admin.uid, {
      ...l,
      id,
      beneficio: l.beneficio ?? org.nombre,
      kgEsperados,
      avisos,
    });
    if (r === "codigo_repetido") {
      return reply.code(409).send({ error: "codigo_repetido", mensaje: `Ya existe un lote con el código ${l.codigo}.` });
    }
    if (r === "entrega_ocupada") {
      return reply.code(409).send({ error: "entrega_ocupada", mensaje: "Otra persona acaba de poner una de esas entregas en otro lote." });
    }
    const lote = (await repo.listarLotes(admin.organizacionId)).find((x) => x.id === id);
    return reply.code(201).send(lote);
  });

  /** Deshace un lote que aún no está en la blockchain ni en un contenedor. */
  app.delete<{ Params: { id: string } }>("/v1/lotes/:id", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    if (!z.uuid().safeParse(req.params.id).success) return reply.code(404).send({ error: "no_encontrado" });
    const r = await repo.eliminarLote(admin.organizacionId, req.params.id);
    if (r === "no_encontrado") return reply.code(404).send({ error: "no_encontrado" });
    if (r === "atestado") {
      return reply.code(409).send({
        error: "atestado",
        mensaje: "El lote ya está en la blockchain o en un contenedor; no se puede deshacer.",
      });
    }
    return reply.code(204).send();
  });

  /** Contenedores de exportación (solo administradores). */
  app.get("/v1/exportaciones", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    return { exportaciones: await repo.listarExportaciones(admin.organizacionId) };
  });

  app.post("/v1/exportaciones", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    const datos = exportacionSchema.safeParse(req.body);
    if (!datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", detalles: datos.error.issues });
    }
    const x = datos.data;
    const { cultivo, rechazos } = evaluarExportacion(x.lotes, await repo.lotesCandidatos(admin.organizacionId, x.lotes));
    if (!cultivo) {
      return reply.code(422).send({
        error: "lotes_excluidos",
        mensaje: `${rechazos.length === 1 ? "Un lote no puede" : `${rechazos.length} lotes no pueden`} ir en el contenedor: ${rechazos[0].motivo}.`,
        rechazos,
      });
    }
    const id = crypto.randomUUID();
    const r = await repo.guardarExportacion(admin.organizacionId, admin.uid, { ...x, id, cultivo });
    if (r === "codigo_repetido") {
      return reply.code(409).send({ error: "codigo_repetido", mensaje: `Ya existe un contenedor con el código ${x.codigo}.` });
    }
    if (r === "lote_ocupado") {
      return reply.code(409).send({ error: "lote_ocupado", mensaje: "Otra persona acaba de poner uno de esos lotes en otro contenedor." });
    }
    const exportacion = (await repo.listarExportaciones(admin.organizacionId)).find((e) => e.id === id);
    return reply.code(201).send(exportacion);
  });

  const respuestaCerrada = {
    error: "cerrada",
    mensaje: "El contenedor ya está cerrado para el paquete EUDR; no se puede cambiar.",
  };

  /** Completa o corrige datos (número de contenedor, DDS...) mientras está abierto. */
  app.patch<{ Params: { id: string } }>("/v1/exportaciones/:id", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    if (!z.uuid().safeParse(req.params.id).success) return reply.code(404).send({ error: "no_encontrada" });
    const cambios = cambiosExportacionSchema.safeParse(req.body);
    if (!cambios.success) {
      return reply.code(422).send({ error: "Datos inválidos", detalles: cambios.error.issues });
    }
    const r = await repo.actualizarExportacion(admin.organizacionId, req.params.id, cambios.data);
    if (r === "no_encontrada") return reply.code(404).send({ error: "no_encontrada" });
    if (r === "cerrada") return reply.code(409).send(respuestaCerrada);
    return (await repo.listarExportaciones(admin.organizacionId)).find((e) => e.id === req.params.id);
  });

  /** Paquete del contenedor (solo administradores), o `null` si ya se respondió 404. */
  async function paquete(req: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) {
    const admin = await activo(req, reply, true);
    if (!admin) return null;
    const p = z.uuid().safeParse(req.params.id).success
      ? await repo.paqueteExportacion(admin.organizacionId, req.params.id)
      : null;
    if (!p) {
      reply.code(404).send({ error: "no_encontrada" });
      return null;
    }
    return { admin, p };
  }
  const nombreArchivo = (codigo: string) => codigo.replace(/[^A-Za-z0-9._-]+/g, "_");

  /**
   * Geolocalización de las fincas de origen para la DDS en TRACES. Solo con el
   * contenedor cerrado: así no llega al importador un GeoJSON con fincas sin
   * verde, y el contenedor queda registrado como consumo (lo que se cobra).
   * El PDF borrador sí se descarga abierto, para revisarlo antes de cerrar.
   */
  app.get<{ Params: { id: string }; Querystring: { productores?: string } }>(
    "/v1/exportaciones/:id/geojson",
    async (req, reply) => {
      const r = await paquete(req, reply);
      if (!r) return;
      if (r.p.exportacion.estado !== "cerrada") {
        return reply.code(409).send({
          error: "abierta",
          mensaje:
            "El GeoJSON para TRACES se descarga con el contenedor cerrado. Ciérralo (número de contenedor y " +
            "todas las fincas en verde) o descarga el PDF borrador para revisarlo con el comprador.",
        });
      }
      return reply
        .header("content-type", "application/geo+json")
        .header("content-disposition", `attachment; filename="${nombreArchivo(r.p.exportacion.codigo)}.geojson"`)
        .send(geojsonTraces(r.p.fincas, { incluirProductor: req.query.productores === "1" }));
    },
  );

  /** Resumen para el comprador (sin datos personales de los productores). */
  app.get<{ Params: { id: string } }>("/v1/exportaciones/:id/pdf", async (req, reply) => {
    const r = await paquete(req, reply);
    if (!r) return;
    return reply
      .header("content-type", "application/pdf")
      .header("content-disposition", `attachment; filename="Paquete-EUDR-${nombreArchivo(r.p.exportacion.codigo)}.pdf"`)
      .send(await pdfPaquete(r.p));
  });

  /** Cierra el paquete EUDR: exige número de contenedor y todas las fincas en verde. */
  app.post<{ Params: { id: string } }>("/v1/exportaciones/:id/cerrar", async (req, reply) => {
    const r = await paquete(req, reply);
    if (!r) return;
    if (r.p.exportacion.estado === "cerrada") return reply.code(409).send(respuestaCerrada);
    const motivos = motivosNoCierre(r.p);
    if (motivos.length > 0) {
      return reply.code(409).send({ error: "incompleto", mensaje: `No se puede cerrar: ${motivos.join(". ")}.`, motivos });
    }
    const estado = await repo.cerrarExportacion(r.admin.organizacionId, req.params.id, r.admin.uid);
    if (estado !== "cambiada") return reply.code(409).send(respuestaCerrada);
    return (await repo.listarExportaciones(r.admin.organizacionId)).find((e) => e.id === req.params.id);
  });

  app.delete<{ Params: { id: string } }>("/v1/exportaciones/:id", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    if (!z.uuid().safeParse(req.params.id).success) return reply.code(404).send({ error: "no_encontrada" });
    const r = await repo.eliminarExportacion(admin.organizacionId, req.params.id);
    if (r === "no_encontrada") return reply.code(404).send({ error: "no_encontrada" });
    if (r === "cerrada") return reply.code(409).send(respuestaCerrada);
    return reply.code(204).send();
  });

  /**
   * Corrección común: sesión activa (o administrador), id válido, cuerpo
   * válido; el resultado se traduce a 200, 403, 404, 409 o 422.
   */
  async function corregir<S extends z.ZodType, T>(
    req: FastifyRequest<{ Params: { id: string } }>,
    reply: FastifyReply,
    opciones: { soloAdmin?: boolean; schema?: S },
    hacer: (u: UsuarioActivo, id: string, datos: z.infer<S>) => Promise<Resultado<T>>,
  ): Promise<{ u: UsuarioActivo; valor: T } | null> {
    const u = await activo(req, reply, opciones.soloAdmin ?? false);
    if (!u) return null;
    if (!correcciones) {
      reply.code(503).send({ error: "sin_correcciones" });
      return null;
    }
    if (!z.uuid().safeParse(req.params.id).success) {
      reply.code(404).send({ error: "no_encontrado" });
      return null;
    }
    let datos: z.infer<S> = undefined as z.infer<S>;
    if (opciones.schema) {
      const r = opciones.schema.safeParse(req.body);
      if (!r.success) {
        const propio = r.error.issues.find((i) => i.path.includes("motivo") || i.path.includes("cedula"))?.message;
        reply.code(422).send({ error: "Datos inválidos", mensaje: propio, detalles: r.error.issues });
        return null;
      }
      datos = r.data;
    }
    const r = await hacer(u, req.params.id, datos);
    if (!r.ok) {
      reply.code(r.status).send({ error: "no_corregible", mensaje: r.mensaje });
      return null;
    }
    return { u, valor: r.valor };
  }

  app.patch<{ Params: { id: string } }>("/v1/entregas/:id", async (req, reply) => {
    const r = await corregir(req, reply, { schema: correccionEntregaSchema }, (u, id, d) => correcciones!.corregirEntrega(u, id, d));
    return r ? r.valor : undefined;
  });

  app.post<{ Params: { id: string } }>("/v1/entregas/:id/anular", async (req, reply) => {
    const r = await corregir(req, reply, { schema: anulacionSchema }, (u, id, d) => correcciones!.anularEntrega(u, id, d.motivo));
    return r ? reply.code(204).send() : undefined;
  });

  app.patch<{ Params: { id: string } }>("/v1/lotes/:id", async (req, reply) => {
    const r = await corregir(req, reply, { soloAdmin: true, schema: correccionLoteSchema }, (u, id, d) => correcciones!.corregirLote(u, id, d));
    return r ? (await repo.listarLotes(r.u.organizacionId)).find((l) => l.id === req.params.id) : undefined;
  });

  app.patch<{ Params: { id: string } }>("/v1/productores/:id", async (req, reply) => {
    const r = await corregir(req, reply, { schema: correccionProductorSchema }, (u, id, d) => correcciones!.corregirProductor(u, id, d));
    return r ? reply.code(204).send() : undefined;
  });

  app.patch<{ Params: { id: string } }>("/v1/fincas/:id", async (req, reply) => {
    const r = await corregir(req, reply, { schema: correccionFincaSchema }, (u, id, d) => correcciones!.corregirFinca(u, id, d));
    return r ? reply.code(204).send() : undefined;
  });

  app.delete<{ Params: { id: string } }>("/v1/fotos/:id", async (req, reply) => {
    const r = await corregir(req, reply, {}, (u, id) => correcciones!.eliminarFoto(u, id));
    if (!r) return;
    // Si falla borrar el archivo, la foto ya no está en la base: queda un
    // archivo huérfano en Storage que solo ve la organización.
    if (r.valor.storagePath) await almacen.borrar(r.valor.storagePath).catch(() => {});
    return reply.code(204).send();
  });

  app.patch<{ Params: { id: string } }>("/v1/verificaciones/:id", async (req, reply) => {
    const r = await corregir(req, reply, { schema: correccionVisitaSchema }, (u, id, d) => correcciones!.corregirVerificacion(u, id, d));
    return r ? reply.code(204).send() : undefined;
  });

  app.post<{ Params: { id: string } }>("/v1/verificaciones/:id/anular", async (req, reply) => {
    const r = await corregir(req, reply, { schema: anulacionSchema }, (u, id, d) => correcciones!.anularVerificacion(u, id, d.motivo));
    return r ? reply.code(204).send() : undefined;
  });

  app.patch<{ Params: { id: string } }>("/v1/temporadas/:id", async (req, reply) => {
    const r = await corregir(req, reply, { soloAdmin: true, schema: correccionTemporadaSchema }, (u, id, d) =>
      correcciones!.corregirTemporada(u, id, d),
    );
    return r ? reply.code(204).send() : undefined;
  });

  app.delete<{ Params: { id: string } }>("/v1/temporadas/:id", async (req, reply) => {
    const r = await corregir(req, reply, { soloAdmin: true }, (u, id) => correcciones!.eliminarTemporada(u, id));
    return r ? reply.code(204).send() : undefined;
  });

  app.get("/v1/invitaciones", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;
    return { invitaciones: await repo.listarInvitaciones(admin.organizacionId) };
  });

  app.post("/v1/invitaciones", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;

    const datos = invitacionSchema.safeParse(req.body);
    if (!datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", detalles: datos.error.issues });
    }
    const creada = await repo.crearInvitacion({ ...datos.data, organizacionId: admin.organizacionId, invitadoPor: admin.uid });
    if (!creada) {
      return reply.code(409).send({ error: "ya_invitado", mensaje: "Ese correo ya tiene una invitación." });
    }
    return reply.code(201).send({ email: datos.data.email, rol: datos.data.rol });
  });

  app.delete<{ Params: { email: string } }>("/v1/invitaciones/:email", async (req, reply) => {
    const admin = await activo(req, reply, true);
    if (!admin) return;

    const email = req.params.email.toLowerCase();
    if (email === admin.email.toLowerCase()) {
      return reply.code(422).send({ error: "propio", mensaje: "No puedes quitarte el acceso a ti mismo." });
    }
    const borrada = await repo.eliminarInvitacion(admin.organizacionId, email);
    if (!borrada) return reply.code(404).send({ error: "no_encontrada" });
    if (borrada.usuarioUid) await identidad.quitarAcceso(borrada.usuarioUid);
    return reply.code(204).send();
  });

  return app;
}
