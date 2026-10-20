import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { OAuth2Client } from "google-auth-library";
import type { Almacen } from "./almacen.ts";
import { buildApp, type VerificarTarea } from "./app.ts";
import { GlobalForestWatch } from "./deforestacion.ts";
import { MapasPublicos } from "./mapas.ts";
import type { Identidad, Rol, VerificarToken } from "./auth.ts";
import { optimism, optimismSepolia } from "viem/chains";
import { ColaPg, EasViem } from "./atestador.ts";
import { CorreccionesPg } from "./correcciones.ts";
import { cuentaKms } from "./kms.ts";
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

// Bucket de Firebase Storage del proyecto (STORAGE_BUCKET en Cloud Run).
const bucket = getStorage().bucket(process.env.STORAGE_BUCKET);
const almacen: Almacen = {
  leer: async (ruta) => {
    const archivo = bucket.file(ruta);
    const [existe] = await archivo.exists();
    if (!existe) return null;
    const [contenido] = await archivo.download();
    return contenido;
  },
  borrar: async (ruta) => {
    await bucket.file(ruta).delete({ ignoreNotFound: true });
  },
};

// Tareas programadas: Cloud Scheduler firma un token OIDC con su cuenta de
// servicio (TAREAS_SA) para la URL del servicio (TAREAS_AUDIENCE).
const oidc = new OAuth2Client();
const verificarTarea: VerificarTarea = async (token) => {
  const audiencia = process.env.TAREAS_AUDIENCE;
  const cuenta = process.env.TAREAS_SA;
  if (!audiencia || !cuenta) {
    console.warn("tarea rechazada: faltan TAREAS_AUDIENCE o TAREAS_SA");
    return false;
  }
  try {
    const ticket = await oidc.verifyIdToken({ idToken: token, audience: audiencia });
    const p = ticket.getPayload();
    if (p?.email === cuenta && p.email_verified === true) return true;
    console.warn(`tarea rechazada: email=${p?.email} email_verified=${p?.email_verified} aud=${p?.aud}`);
    return false;
  } catch (e) {
    console.warn(`tarea rechazada: token inválido (${(e as Error).message})`);
    return false;
  }
};

// Chequeo satelital: por defecto, mapas públicos (JRC 2020 + Hansen), sin
// cuentas ni keys. Con SATELITE=gfw y GFW_API_KEY, la Data API de GFW.
const satelite =
  process.env.SATELITE === "gfw" && process.env.GFW_API_KEY
    ? new GlobalForestWatch(process.env.GFW_API_KEY)
    : new MapasPublicos();

const { pool } = await crearPool();

// Attestations: clave en Cloud KMS y red EAS_RED (optimism-sepolia u optimism).
const atestador = process.env.KMS_KEY_VERSION
  ? {
      cola: new ColaPg(pool),
      red: new EasViem(
        await cuentaKms(process.env.KMS_KEY_VERSION),
        process.env.EAS_RED === "optimism" ? optimism : optimismSepolia,
        process.env.RPC_URL,
      ),
    }
  : null;

const app = buildApp({
  repo: new PgRepo(pool),
  verificarToken,
  identidad,
  almacen,
  satelite,
  verificarTarea,
  atestador,
  correcciones: new CorreccionesPg(pool),
});

await app.listen({ host: "0.0.0.0", port: Number(process.env.PORT ?? 8080) });
