import { AuthTypes, Connector, IpAddressTypes } from "@google-cloud/cloud-sql-connector";
import pg from "pg";

/**
 * Pool de PostgreSQL. Dos modos:
 *
 * - `INSTANCE_CONNECTION_NAME` (Cloud SQL): conecta con el conector oficial y
 *   autenticación IAM, sin contraseñas. El usuario de la base es la identidad
 *   de Google que corre el proceso: tu correo en desarrollo
 *   (`gcloud auth application-default login`) o la cuenta de servicio en
 *   Cloud Run. Se indica en `DB_USER`.
 * - `DATABASE_URL`: cualquier PostgreSQL con PostGIS (local, Neon, etc.).
 */
export async function crearPool(): Promise<{ pool: pg.Pool; cerrar: () => Promise<void> }> {
  const instancia = process.env.INSTANCE_CONNECTION_NAME;
  if (!instancia) {
    if (!process.env.DATABASE_URL) {
      throw new Error("Define INSTANCE_CONNECTION_NAME (Cloud SQL) o DATABASE_URL en backend/.env");
    }
    const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
    return { pool, cerrar: () => pool.end() };
  }

  if (!process.env.DB_USER || !process.env.DB_NAME) {
    throw new Error("Con Cloud SQL define DB_USER (usuario IAM) y DB_NAME en backend/.env");
  }
  const connector = new Connector();
  const opciones = await connector.getOptions({
    instanceConnectionName: instancia,
    ipType: IpAddressTypes.PUBLIC,
    authType: AuthTypes.IAM,
  });
  const pool = new pg.Pool({
    ...opciones,
    user: process.env.DB_USER,
    database: process.env.DB_NAME,
    max: 5,
  });
  return {
    pool,
    cerrar: async () => {
      await pool.end();
      connector.close();
    },
  };
}
