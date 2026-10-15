/** Aplica en orden las migraciones de db/migrations que aún no se aplicaron. */
import { readdirSync, readFileSync } from "node:fs";
import { crearPool } from "../src/db.ts";

const dir = new URL("../db/migrations/", import.meta.url);
const { pool, cerrar } = await crearPool();
const client = await pool.connect();

try {
  await client.query(
    "CREATE TABLE IF NOT EXISTS migraciones (nombre text PRIMARY KEY, aplicada_en timestamptz NOT NULL DEFAULT now())",
  );
  const { rows } = await client.query<{ nombre: string }>("SELECT nombre FROM migraciones");
  const aplicadas = new Set(rows.map((r) => r.nombre));

  let nuevas = 0;
  for (const archivo of readdirSync(dir).filter((f) => f.endsWith(".sql")).sort()) {
    if (aplicadas.has(archivo)) continue;
    await client.query("BEGIN");
    try {
      await client.query(readFileSync(new URL(archivo, dir), "utf8"));
      await client.query("INSERT INTO migraciones (nombre) VALUES ($1)", [archivo]);
      await client.query("COMMIT");
      console.log(`Aplicada: ${archivo}`);
      nuevas++;
    } catch (e) {
      await client.query("ROLLBACK");
      throw new Error(`Falló ${archivo}: ${(e as Error).message}`);
    }
  }
  if (nuevas === 0) console.log("La base ya estaba al día.");
} finally {
  client.release();
  await cerrar();
}
