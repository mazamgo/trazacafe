import Fastify, { type FastifyReply, type FastifyRequest } from "fastify";
import { z } from "zod";
import { estaActivo, type Identidad, type Usuario, type UsuarioActivo, type VerificarToken } from "./auth.ts";
import { AccesoDenegado, type Repo } from "./repo.ts";
import { syncSchema } from "./sync.ts";

const invitacionSchema = z.object({
  email: z.email().transform((e) => e.toLowerCase()),
  rol: z.enum(["admin", "tecnico"]),
});

export function buildApp({
  repo,
  verificarToken,
  identidad,
}: {
  repo: Repo;
  verificarToken: VerificarToken;
  identidad: Identidad;
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
      throw e;
    }
    const { productores, fincas, fotos } = datos.data;
    return { recibidos: { productores: productores.length, fincas: fincas.length, fotos: fotos.length } };
  });

  /** Corrige un error de campo: borra una finca que aún no se atestó. */
  app.delete<{ Params: { id: string } }>("/v1/fincas/:id", async (req, reply) => {
    const usuario = await activo(req, reply);
    if (!usuario) return;
    if (!z.uuid().safeParse(req.params.id).success) return reply.code(404).send({ error: "no_encontrada" });

    const r = await repo.eliminarFinca(usuario.organizacionId, req.params.id);
    if (r === "no_encontrada") return reply.code(404).send({ error: "no_encontrada" });
    if (r === "atestada") {
      return reply.code(409).send({
        error: "atestada",
        mensaje: "Esta finca ya está registrada en la blockchain; hay que revocar su attestation.",
      });
    }
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
