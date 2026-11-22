/**
 * Da o quita el acceso a la consola del propietario (GoProduction): el custom
 * claim `propietario`. Nunca se asigna por invitación. La cuenta debe tener
 * verificación en dos pasos.
 *
 *   npm run propietario -- --email ana@goproduction.com
 *   npm run propietario -- --email ana@goproduction.com --quitar
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { parseArgs } from "node:util";

const { values } = parseArgs({ options: { email: { type: "string" }, quitar: { type: "boolean", default: false } } });
if (!values.email) {
  console.error("Uso: npm run propietario -- --email <correo de Google> [--quitar]");
  process.exit(1);
}
initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });
const auth = getAuth();
const u = await auth.getUserByEmail(values.email.trim().toLowerCase());
const { propietario: _, ...resto } = u.customClaims ?? {};
await auth.setCustomUserClaims(u.uid, values.quitar ? resto : { ...resto, propietario: true });
// La sesión vigente pide un token nuevo para ver el cambio.
await auth.revokeRefreshTokens(u.uid);
console.log(`${values.email}: ${values.quitar ? "ya no es" : "ahora es"} propietario. Debe volver a entrar.`);
