import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import pg from "pg";
import { buildApp, type VerificarToken } from "./app.ts";
import { PgRepo } from "./repo.ts";

initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });

// La cooperativa del técnico viaja como custom claim `cooperativaId`
// en su token de Firebase.
const verificarToken: VerificarToken = async (token) => {
  try {
    const decoded = await getAuth().verifyIdToken(token);
    const cooperativaId = decoded.cooperativaId;
    return typeof cooperativaId === "string" ? { uid: decoded.uid, cooperativaId } : null;
  } catch {
    return null;
  }
};

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const app = buildApp({ repo: new PgRepo(pool), verificarToken });

await app.listen({ host: "0.0.0.0", port: Number(process.env.PORT ?? 8080) });
