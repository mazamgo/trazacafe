/**
 * Genera test-vectors.json: casos de prueba compartidos entre la app Flutter
 * y el backend para que el hash y el área se calculen igual en ambos lados.
 * El área de referencia sale de Turf.js.
 *
 *   npm run vectors
 */
import { writeFileSync } from "node:fs";
import area from "@turf/area";
import { coordenadasCanonicas, geoHash, type Coordenada } from "../src/index.ts";

const casos: { nombre: string; coords: Coordenada[] }[] = [
  {
    nombre: "Cuadro de ~1.2 ha en Jinotega",
    coords: [
      [-86.0023, 13.091],
      [-86.0013, 13.091],
      [-86.0013, 13.092],
      [-86.0023, 13.092],
    ],
  },
  {
    nombre: "Finca irregular de ~10 ha en Matagalpa",
    coords: [
      [-85.917512, 12.925431],
      [-85.915101, 12.925877],
      [-85.914333, 12.923562],
      [-85.916049, 12.922318],
      [-85.918204, 12.923940],
    ],
  },
  {
    nombre: "Punto único (finca < 4 ha)",
    coords: [[-86.235, 13.6305]],
  },
];

const vectores = casos.map(({ nombre, coords }) => {
  const anillo = [...coords, coords[0]];
  const areaHa =
    coords.length >= 3 ? area({ type: "Polygon", coordinates: [anillo] }) / 10_000 : 0;
  return {
    nombre,
    coords,
    canonico: coordenadasCanonicas(coords),
    geoHash: geoHash(coords),
    areaHa: Number(areaHa.toFixed(6)),
  };
});

writeFileSync(new URL("../test-vectors.json", import.meta.url), JSON.stringify(vectores, null, 2) + "\n");
console.log(`test-vectors.json: ${vectores.length} casos`);
