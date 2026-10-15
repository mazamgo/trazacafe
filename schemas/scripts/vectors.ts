/**
 * Genera test-vectors.json: casos de prueba compartidos entre la app Flutter
 * y el backend para que el hash, el área y la validez del polígono se
 * calculen igual en ambos lados. El área y los cruces de referencia salen de
 * Turf.js, no de nuestro código.
 *
 *   npm run vectors
 */
import { writeFileSync } from "node:fs";
import area from "@turf/area";
import kinks from "@turf/kinks";
import { coordenadasCanonicas, geoHash, problemaPoligono, type Coordenada, type ProblemaPoligono } from "../src/index.ts";

const casos: { nombre: string; coords: Coordenada[]; problema: ProblemaPoligono | null }[] = [
  {
    nombre: "Cuadro de ~1.2 ha en Jinotega",
    coords: [
      [-86.0023, 13.091],
      [-86.0013, 13.091],
      [-86.0013, 13.092],
      [-86.0023, 13.092],
    ],
    problema: null,
  },
  {
    nombre: "Finca irregular de ~10 ha en Matagalpa",
    coords: [
      [-85.917512, 12.925431],
      [-85.915101, 12.925877],
      [-85.914333, 12.923562],
      [-85.916049, 12.922318],
      [-85.918204, 12.92394],
    ],
    problema: null,
  },
  {
    nombre: "Finca en L (cóncava pero válida)",
    coords: [
      [-86.0023, 13.091],
      [-86.0003, 13.091],
      [-86.0003, 13.0915],
      [-86.0013, 13.0915],
      [-86.0013, 13.092],
      [-86.0023, 13.092],
    ],
    problema: null,
  },
  {
    nombre: "Moño: dos vértices en orden equivocado",
    coords: [
      [-86.0023, 13.091],
      [-86.0013, 13.092],
      [-86.0013, 13.091],
      [-86.0023, 13.092],
    ],
    problema: "se_cruza",
  },
  {
    nombre: "Lindero caminado que se cruza al cerrar",
    coords: [
      [-86.0023, 13.091],
      [-86.0013, 13.091],
      [-86.0013, 13.092],
      [-86.0023, 13.092],
      [-86.0018, 13.0905],
    ],
    problema: "se_cruza",
  },
  {
    nombre: "Espina: el lindero regresa sobre sí mismo",
    coords: [
      [-86.0023, 13.091],
      [-86.0013, 13.091],
      [-86.0013, 13.092],
      [-86.0013, 13.0915],
      [-86.0023, 13.092],
    ],
    problema: "se_cruza",
  },
  {
    nombre: "Punto repetido (GPS tocado dos veces)",
    coords: [
      [-86.0023, 13.091],
      [-86.0013, 13.091],
      [-86.0013, 13.091],
      [-86.0023, 13.092],
    ],
    problema: "puntos_repetidos",
  },
  {
    nombre: "Punto único (finca < 4 ha)",
    coords: [[-86.235, 13.6305]],
    problema: "pocos_puntos",
  },
];

const vectores = casos.map(({ nombre, coords, problema }) => {
  const poligono = { type: "Polygon" as const, coordinates: [[...coords, coords[0]]] };

  // Verificación contra Turf para los cruces simples (moño, cierre): si Turf
  // ve cruces, nuestro algoritmo también debe verlos, y al revés.
  if (coords.length >= 3 && problema !== "puntos_repetidos" && !nombre.startsWith("Espina")) {
    const turfCruza = kinks(poligono).features.length > 0;
    if (turfCruza !== (problema === "se_cruza")) throw new Error(`Turf no coincide en: ${nombre}`);
  }
  if (problemaPoligono(coords) !== problema) {
    throw new Error(`problemaPoligono da ${problemaPoligono(coords)} en "${nombre}", se esperaba ${problema}`);
  }

  return {
    nombre,
    coords,
    canonico: coordenadasCanonicas(coords),
    geoHash: geoHash(coords),
    areaHa: Number((coords.length >= 3 ? area(poligono) / 10_000 : 0).toFixed(6)),
    problema,
  };
});

writeFileSync(new URL("../test-vectors.json", import.meta.url), JSON.stringify(vectores, null, 2) + "\n");
console.log(`test-vectors.json: ${vectores.length} casos`);
