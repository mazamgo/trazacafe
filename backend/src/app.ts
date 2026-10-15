import Fastify from "fastify";
import { AccesoDenegado, type Repo } from "./repo.ts";
import { syncSchema } from "./sync.ts";

/** Usuario autenticado: técnico de campo de una cooperativa. */
export interface Usuario {
  uid: string;
  cooperativaId: string;
}

/** Valida el token de Firebase del encabezado Authorization. */
export type VerificarToken = (token: string) => Promise<Usuario | null>;

export function buildApp({ repo, verificarToken }: { repo: Repo; verificarToken: VerificarToken }) {
  const app = Fastify({ logger: process.env.NODE_ENV !== "test" });

  app.get("/health", async () => ({ ok: true }));

  app.post("/v1/sync", async (req, reply) => {
    const token = req.headers.authorization?.replace(/^Bearer /, "");
    const usuario = token ? await verificarToken(token) : null;
    if (!usuario) return reply.code(401).send({ error: "No autenticado" });

    const datos = syncSchema.safeParse(req.body);
    if (!datos.success) {
      return reply.code(422).send({ error: "Datos inválidos", detalles: datos.error.issues });
    }
    try {
      await repo.guardarSync(usuario.cooperativaId, datos.data);
    } catch (e) {
      if (e instanceof AccesoDenegado) return reply.code(403).send({ error: e.message });
      throw e;
    }
    return { recibidos: { productores: datos.data.productores.length, fincas: datos.data.fincas.length } };
  });

  return app;
}
