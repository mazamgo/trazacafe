/**
 * Registra una organización (cooperativa, exportadora o beneficio) e invita a
 * su primer administrador. El administrador entra a la app con "Entrar con
 * Google" usando ese correo y desde ahí invita a sus técnicos.
 *
 *   npm run crear-organizacion -- --nombre "Cooperativa Ejemplo R.L." --admin gerente@gmail.com
 *   npm run crear-organizacion -- --nombre "Exportadora X" --tipo exportadora --admin ana@gmail.com
 */
import { randomUUID } from "node:crypto";
import { parseArgs } from "node:util";
import pg from "pg";

const TIPOS = ["cooperativa", "exportadora", "beneficio", "otra"];

const { values } = parseArgs({
  options: {
    nombre: { type: "string" },
    tipo: { type: "string", default: "cooperativa" },
    admin: { type: "string" },
  },
});
if (!values.nombre || !values.admin) {
  console.error('Uso: npm run crear-organizacion -- --nombre "<nombre>" --admin <correo de Google> [--tipo cooperativa|exportadora|beneficio|otra]');
  process.exit(1);
}
if (!TIPOS.includes(values.tipo!)) {
  console.error(`--tipo debe ser uno de: ${TIPOS.join(", ")}`);
  process.exit(1);
}
const admin = values.admin.trim().toLowerCase();
if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(admin)) {
  console.error("--admin debe ser un correo válido.");
  process.exit(1);
}

const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
const id = randomUUID();
try {
  await client.query("BEGIN");
  await client.query("INSERT INTO organizaciones (id, nombre, tipo) VALUES ($1, $2, $3)", [id, values.nombre, values.tipo]);
  await client.query(
    "INSERT INTO invitaciones (email, organizacion_id, rol, invitado_por) VALUES ($1, $2, 'admin', 'script')",
    [admin, id],
  );
  await client.query("COMMIT");
} catch (e) {
  await client.query("ROLLBACK");
  if ((e as { code?: string }).code === "23505") {
    console.error(`${admin} ya tiene una invitación en otra organización.`);
    process.exit(1);
  }
  throw e;
} finally {
  await client.end();
}

console.log(`Organización creada: ${values.nombre} (${values.tipo})`);
console.log(`ID: ${id}`);
console.log(`Administrador invitado: ${admin} → debe entrar con "Entrar con Google".`);
