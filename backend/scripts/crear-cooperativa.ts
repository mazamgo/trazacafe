/**
 * Registra una cooperativa en la base de datos e imprime su UUID, que luego
 * se usa en `npm run crear-tecnico`.
 *
 *   npm run crear-cooperativa -- --nombre "Cooperativa Ejemplo R.L."
 */
import { randomUUID } from "node:crypto";
import { parseArgs } from "node:util";
import pg from "pg";

const { values } = parseArgs({ options: { nombre: { type: "string" } } });
if (!values.nombre) {
  console.error('Uso: npm run crear-cooperativa -- --nombre "<nombre>"');
  process.exit(1);
}

const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
const id = randomUUID();
await client.query("INSERT INTO cooperativas (id, nombre) VALUES ($1, $2)", [id, values.nombre]);
await client.end();
console.log(`Cooperativa creada: ${values.nombre}\nID: ${id}`);
