import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { buildApp } from "./app.ts";
import type { Identidad, Rol, VerificarToken } from "./auth.ts";
import { crearPool } from "./db.ts";
import { PgRepo } from "./repo.ts";

initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });
const auth = getAuth();

// `checkRevoked` hace que un acceso quitado deje de servir al instante y no
// cuando vence el token (hasta 1 hora). Solo se aceptan correos verificados,
// como los de Google.
const verificarToken: VerificarToken = async (token) => {
  try {
    const d = await auth.verifyIdToken(token, true);
    if (!d.email || !d.email_verified) return null;
    return {
      uid: d.uid,
      email: d.email,
      organizacionId: typeof d.organizacionId === "string" ? d.organizacionId : undefined,
      rol: d.rol === "admin" || d.rol === "tecnico" ? (d.rol as Rol) : undefined,
    };
  } catch {
    return null;
  }
};

const identidad: Identidad = {
  asignarAcceso: (uid, acceso) => auth.setCustomUserClaims(uid, acceso),
  quitarAcceso: async (uid) => {
    await auth.setCustomUserClaims(uid, null);
    await auth.revokeRefreshTokens(uid);
  },
};

const { pool } = await crearPool();
const app = buildApp({ repo: new PgRepo(pool), verificarToken, identidad });

await app.listen({ host: "0.0.0.0", port: Number(process.env.PORT ?? 8080) });
