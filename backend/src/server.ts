import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { OAuth2Client } from "google-auth-library";
import type { Almacen } from "./almacen.ts";
import { buildApp, type VerificarTarea } from "./app.ts";
import { GlobalForestWatch, MapasConAlertas } from "./deforestacion.ts";
import { MapasPublicos } from "./mapas.ts";
import type { Identidad, Rol, VerificarToken } from "./auth.ts";
import { optimism, optimismSepolia } from "viem/chains";
import { ColaPg, EasViem } from "./atestador.ts";
import { CorreccionesPg } from "./correcciones.ts";
import { EliminacionesPg } from "./eliminacion.ts";
import { cuentaKms } from "./kms.ts";
import { crearPool } from "./db.ts";
import { ProveedoresPg } from "./proveedores.ts";
import nodemailer from "nodemailer";
import { CompradoresPg, type Correo } from "./compradores.ts";
import { ControlesPg } from "./control.ts";
import { NotificacionesPg, type EnviarPush } from "./notificaciones.ts";
import { ReportesPg } from "./reportes.ts";
import { PgRepo } from "./repo.ts";
import { VerificadorPg } from "./verificador.ts";

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
  eliminarUsuario: async (uid) => {
    try {
      await auth.deleteUser(uid);
    } catch (e) {
      if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
    }
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
// cuentas ni keys. Con SATELITE=gfw y GFW_API_KEY, los mismos mapas más las
// alertas integradas de GFW (modo combinado).
const satelite =
  process.env.SATELITE === "gfw" && process.env.GFW_API_KEY
    ? new MapasConAlertas(new MapasPublicos(), new GlobalForestWatch(process.env.GFW_API_KEY))
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

// FCM, del mismo proyecto de Firebase: los avisos se muestran como
// notificación del sistema y llevan la pantalla que se abre al tocarlos.
const enviarPush: EnviarPush = async (tokens, m) => {
  const r = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: m.titulo, body: m.cuerpo },
    data: { pantalla: m.pantalla },
    android: { priority: "high" },
  });
  return r.responses.flatMap((x, i) =>
    !x.success &&
    ["messaging/registration-token-not-registered", "messaging/invalid-registration-token"].includes(x.error?.code ?? "")
      ? [tokens[i]]
      : [],
  );
};

// Correo de las alertas del importador: SMTP de un servicio de envío (Brevo,
// SendGrid, Gmail con contraseña de aplicación). Sin CORREO_SMTP_URL, las
// alertas se ven en el portal y no se manda correo.
const correo: Correo | null = process.env.CORREO_SMTP_URL
  ? (() => {
      const transporte = nodemailer.createTransport(process.env.CORREO_SMTP_URL);
      const de = process.env.CORREO_REMITENTE ?? "TrazaCafé <no-responder@trazacafe.app>";
      return async (para, asunto, texto) => {
        await transporte.sendMail({ from: de, to: para, subject: asunto, text: texto });
      };
    })()
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
  eliminaciones: new EliminacionesPg(pool),
  proveedores: new ProveedoresPg(pool),
  reportes: new ReportesPg(pool),
  notificaciones: new NotificacionesPg(pool, enviarPush),
  controles: new ControlesPg(pool),
  compradores: new CompradoresPg(pool),
  correo,
  verificador: new VerificadorPg(pool),
  ...(process.env.ORIGENES_PANEL ? { origenesPanel: process.env.ORIGENES_PANEL.split(",").map((o) => o.trim()) } : {}),
});

await app.listen({ host: "0.0.0.0", port: Number(process.env.PORT ?? 8080) });
