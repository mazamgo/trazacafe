/**
 * Registra una organización (cooperativa, exportadora o beneficio) e invita a
 * su primer administrador. El administrador entra a la app con "Entrar con
 * Google" usando ese correo y desde ahí invita a sus técnicos.
 *
 *   npm run crear-organizacion -- --nombre "Cooperativa Ejemplo R.L." --admin gerente@gmail.com
 *   npm run crear-organizacion -- --nombre "Exportadora X" --tipo exportadora --admin ana@gmail.com
 *   npm run crear-organizacion -- --nombre "Coop. Cacao" --cultivos cacao --admin luis@gmail.com
 *   (--cultivos: lista separada por comas; por defecto, cafe)
 */
import { randomUUID } from "node:crypto";
import { parseArgs } from "node:util";
import { ID_CULTIVOS } from "@trazacafe/eudr-eas-schemas";
import { crearPool } from "../src/db.ts";

const TIPOS = ["cooperativa", "exportadora", "beneficio", "otra"];

const { values } = parseArgs({
  options: {
    nombre: { type: "string" },
    tipo: { type: "string", default: "cooperativa" },
    admin: { type: "string" },
    cultivos: { type: "string", default: "cafe" },
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
const cultivos = [...new Set(values.cultivos!.split(",").map((c) => c.trim()).filter(Boolean))];
const desconocidos = cultivos.filter((c) => !(ID_CULTIVOS as string[]).includes(c));
if (cultivos.length === 0 || desconocidos.length > 0) {
  console.error(`--cultivos debe ser una lista de: ${ID_CULTIVOS.join(", ")}`);
  process.exit(1);
}
const admin = values.admin.trim().toLowerCase();
if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(admin)) {
  console.error("--admin debe ser un correo válido.");
  process.exit(1);
}

const { pool, cerrar } = await crearPool();
const client = await pool.connect();
const id = randomUUID();
let duplicado = false;
try {
  await client.query("BEGIN");
  await client.query("INSERT INTO organizaciones (id, nombre, tipo, cultivos) VALUES ($1, $2, $3, $4)", [id, values.nombre, values.tipo, cultivos]);
  await client.query(
    "INSERT INTO invitaciones (email, organizacion_id, rol, invitado_por) VALUES ($1, $2, 'admin', 'script')",
    [admin, id],
  );
  await client.query("COMMIT");
} catch (e) {
  await client.query("ROLLBACK");
  if ((e as { code?: string }).code !== "23505") throw e;
  duplicado = true;
} finally {
  client.release();
  await cerrar();
}
if (duplicado) {
  console.error(`${admin} ya tiene una invitación en otra organización.`);
  process.exit(1);
}

console.log(`Organización creada: ${values.nombre} (${values.tipo}; ${cultivos.join(", ")})`);
console.log(`ID: ${id}`);
console.log(`Administrador invitado: ${admin} → debe entrar con "Entrar con Google".`);
