/**
 * Crea la cuenta de un técnico de campo en Firebase Authentication y le
 * asigna su cooperativa (custom claim `cooperativaId`, que exige la API).
 * No define contraseña: imprime un enlace para que el técnico la elija.
 *
 *   npm run crear-tecnico -- --email tecnico@coop.org --cooperativa <uuid>
 *
 * Requiere credenciales de administrador:
 *   gcloud auth application-default login
 */
import { parseArgs } from "node:util";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const { values } = parseArgs({
  options: {
    email: { type: "string" },
    cooperativa: { type: "string" },
    nombre: { type: "string" },
  },
});
if (!values.email || !values.cooperativa) {
  console.error("Uso: npm run crear-tecnico -- --email <correo> --cooperativa <uuid> [--nombre <nombre>]");
  process.exit(1);
}
if (!/^[0-9a-f-]{36}$/i.test(values.cooperativa)) {
  console.error("--cooperativa debe ser el UUID de la cooperativa en la base de datos.");
  process.exit(1);
}

initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });
const auth = getAuth();

const existente = await auth.getUserByEmail(values.email).catch(() => null);
const usuario =
  existente ?? (await auth.createUser({ email: values.email, displayName: values.nombre, emailVerified: false }));
await auth.setCustomUserClaims(usuario.uid, { cooperativaId: values.cooperativa });

const enlace = await auth.generatePasswordResetLink(values.email);
console.log(`${existente ? "Actualizado" : "Creado"}: ${values.email} (uid ${usuario.uid})`);
console.log(`Cooperativa: ${values.cooperativa}`);
console.log(`Envía este enlace al técnico para que elija su contraseña:\n${enlace}`);
