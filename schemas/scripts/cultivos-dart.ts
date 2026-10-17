/**
 * Genera app/lib/domain/cultivos_generados.dart desde schemas/cultivos.json, para que
 * la app y la API usen los mismos cultivos y estados.
 *
 *   npm run cultivos-dart
 *
 * La prueba app/test/cultivos_test.dart falla si el archivo generado quedó
 * desactualizado respecto al JSON.
 */
import { writeFileSync } from "node:fs";
import { cultivos } from "../src/cultivos.ts";

const dart = (s: string) => `'${s.replaceAll("\\", "\\\\").replaceAll("'", "\\'")}'`;

const cuerpo = cultivos
  .map(
    (c) => `  Cultivo(
    id: ${dart(c.id)},
    nombre: ${dart(c.nombre)},
    codigoHS: ${dart(c.codigoHS)},
    color: 0xFF${c.color.slice(1).toUpperCase()},
    maxKgEntrega: ${c.maxKgEntrega},
    estados: [
${c.estados.map((e) => `      EstadoEntrega(id: ${dart(e.id)}, nombre: ${dart(e.nombre)}, corto: ${dart(e.corto)}),`).join("\n")}
    ],
  ),`,
  )
  .join("\n");

const archivo = `// GENERADO por schemas/scripts/cultivos-dart.ts desde schemas/cultivos.json.
// No editar a mano: cambia el JSON y corre \`npm run cultivos-dart\` en schemas/.
part of 'cultivos.dart';

const cultivosGenerados = <Cultivo>[
${cuerpo}
];
`;

writeFileSync(new URL("../../app/lib/domain/cultivos_generados.dart", import.meta.url), archivo);
console.log(`app/lib/domain/cultivos_generados.dart: ${cultivos.length} cultivos`);
