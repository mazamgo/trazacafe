import Fastify, { type FastifyReply, type FastifyRequest } from "fastify";
import { z } from "zod";
import { rutaFoto, sha256Hex, type Almacen } from "./almacen.ts";
import { estaActivo, type Identidad, type Usuario, type UsuarioActivo, type VerificarToken } from "./auth.ts";
import { revisar, type FuenteSatelital } from "./deforestacion.ts";
import { AccesoDenegado, VersionDesfasada, type Repo } from "./repo.ts";
import { syncSchema, temporadaSchema } from "./sync.ts";

const invitacionSchema = z.object({
  email: z.email().transform((e) => e.toLowerCase()),
  rol: z.enum(["admin", "tecnico"]),
});

/** Fincas que revisa cada ejecución diaria de la tarea programada. */
const FINCAS_POR_TAREA = 50;

/** Valida el token OIDC con el que Cloud Scheduler llama a las tareas. */
export type VerificarTarea = (token: string) => Promise<boolean>;

export function buildApp({
  repo,
  verificarToken,
  identidad,
  almacen,
  satelite,
  verificarTarea,
}: {
  repo: Repo;
  verificarToken: VerificarToken;
  identidad: Identidad;
  almacen: Almacen;
  /** `null` mientras no haya API key de Global Forest Watch. */
  satelite: FuenteSatelital | null;
  verificarTarea: VerificarTarea;
}) {
  const app = Fastify({ logger: process.env.NODE_ENV !== "test" });

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
    return repo.datosOrganizacion(usuario.organizacionId);
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
    // Si falla borrar un archivo, la finca ya no existe: queda un archivo
    // huérfano en Storage, que no expone nada (solo lo lee la organización).
    await Promise.allSettled(r.archivos.map((a) => almacen.borrar(a)));
    return reply.code(204).send();
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
