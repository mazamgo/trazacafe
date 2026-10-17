import { createHash } from "node:crypto";
import {
  encodeAbiParameters,
  encodePacked,
  keccak256,
  pad,
  parseAbiParameters,
  zeroAddress,
  type Address,
  type Hex,
} from "viem";
import definiciones from "../schemas.json" with { type: "json" };

export * from "./cultivos.ts";

export type NombreEsquema = keyof typeof definiciones;

export interface Esquema {
  nombre: NombreEsquema;
  descripcion: string;
  schema: string;
  revocable: boolean;
}

/** Contratos de EAS: vienen preinstalados en todas las cadenas del OP Stack. */
export const EAS_ADDRESS: Address = "0x4200000000000000000000000000000000000021";
export const SCHEMA_REGISTRY_ADDRESS: Address = "0x4200000000000000000000000000000000000020";

export const esquemas: Esquema[] = (Object.keys(definiciones) as NombreEsquema[]).map(
  (nombre) => ({ nombre, ...definiciones[nombre] }),
);

/** UID del esquema, igual que lo calcula el SchemaRegistry de EAS. */
export function schemaUid(schema: string, revocable: boolean, resolver: Address = zeroAddress): Hex {
  return keccak256(encodePacked(["string", "address", "bool"], [schema, resolver, revocable]));
}

export function esquema(nombre: NombreEsquema): Esquema {
  return esquemas.find((e) => e.nombre === nombre)!;
}

/** Codifica los datos de una attestation tal como los espera EAS (abi.encode). */
export function codificar(nombre: NombreEsquema, valores: readonly unknown[]): Hex {
  return encodeAbiParameters(parseAbiParameters(esquema(nombre).schema), valores as never);
}

/** UUID (`xxxxxxxx-xxxx-…`) a bytes32, rellenado con ceros a la derecha. */
export function uuidABytes32(uuid: string): Hex {
  const hex = uuid.replaceAll("-", "").toLowerCase();
  if (!/^[0-9a-f]{32}$/.test(hex)) throw new Error(`UUID inválido: ${uuid}`);
  return pad(`0x${hex}`, { size: 32, dir: "right" });
}

export interface DatosFinca {
  fincaId: string;
  /** Versión del lindero (1 la primera; sube con cada lindero nuevo). */
  version: number;
  /** Id de cultivos.json (`cafe`, `cacao`). */
  cultivo: string;
  geoHash: Hex;
  areaHa: number;
  docsHash: Hex;
}

export function codificarFinca(d: DatosFinca): Hex {
  return codificar("Finca", [
    uuidABytes32(d.fincaId),
    d.version,
    d.cultivo,
    d.geoHash,
    Math.round(d.areaHa * 100),
    d.docsHash,
  ]);
}

/**
 * Huella de varios hashes (p. ej. las fotos de una finca): SHA-256 de los
 * hashes en minúsculas, ordenados y unidos por comas. Sin hashes, cero.
 */
export function hashDeHashes(hashes: string[]): Hex {
  if (hashes.length === 0) return `0x${"0".repeat(64)}`;
  const texto = hashes.map((h) => h.toLowerCase()).sort().join(",");
  return `0x${createHash("sha256").update(texto, "utf8").digest("hex")}`;
}

/** Kg con dos decimales como entero (345.5 kg → 34550), para los esquemas. */
export const kgX100 = (kg: number) => Math.round(kg * 100);

/** Coordenada GeoJSON: [lon, lat]. */
export type Coordenada = [number, number];

/**
 * Texto canónico de las coordenadas: `lon,lat;lon,lat` con 6 decimales.
 * Debe coincidir con `coordenadasCanonicas` de la app Flutter
 * (app/lib/domain/geo.dart); ambos se prueban con test-vectors.json.
 */
export function coordenadasCanonicas(coords: Coordenada[]): string {
  return coords.map(([lon, lat]) => `${lon.toFixed(6)},${lat.toFixed(6)}`).join(";");
}

/** Hash SHA-256 (`0x…`) de las coordenadas: lo que va en la attestation. */
export function geoHash(coords: Coordenada[]): Hex {
  return `0x${createHash("sha256").update(coordenadasCanonicas(coords), "utf8").digest("hex")}`;
}

export type ProblemaPoligono = "pocos_puntos" | "puntos_repetidos" | "se_cruza";

/**
 * Por qué un polígono no es válido para el EUDR (TRACES rechaza geometrías
 * inválidas), o `null` si es válido. Recibe el anillo abierto, sin repetir el
 * primer punto al final. Mismo algoritmo que `problemaPoligono` de la app
 * (app/lib/domain/geo.dart); ambos se prueban con test-vectors.json.
 */
export function problemaPoligono(coords: Coordenada[]): ProblemaPoligono | null {
  const n = coords.length;
  if (n < 3) return "pocos_puntos";
  const p = (i: number) => coords[i % n];

  for (let i = 0; i < n; i++) {
    if (p(i)[0] === p(i + 1)[0] && p(i)[1] === p(i + 1)[1]) return "puntos_repetidos";
  }
  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      const [a, b, c, d] = [p(i), p(i + 1), p(j), p(j + 1)];
      if (j === i + 1) {
        // Lados seguidos comparten b: solo fallan si el segundo "regresa" sobre el primero.
        if (seDevuelve(a, b, d)) return "se_cruza";
      } else if (i === 0 && j === n - 1) {
        // El último lado termina en el primer punto (a).
        if (seDevuelve(b, a, c)) return "se_cruza";
      } else if (segmentosSeTocan(a, b, c, d)) {
        return "se_cruza";
      }
    }
  }
  return null;
}

function orientacion(p: Coordenada, q: Coordenada, r: Coordenada): number {
  return Math.sign((q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]));
}

function dentroDelRectangulo(p: Coordenada, q: Coordenada, r: Coordenada): boolean {
  return (
    Math.min(p[0], q[0]) <= r[0] && r[0] <= Math.max(p[0], q[0]) &&
    Math.min(p[1], q[1]) <= r[1] && r[1] <= Math.max(p[1], q[1])
  );
}

function segmentosSeTocan(a: Coordenada, b: Coordenada, c: Coordenada, d: Coordenada): boolean {
  const o1 = orientacion(a, b, c);
  const o2 = orientacion(a, b, d);
  const o3 = orientacion(c, d, a);
  const o4 = orientacion(c, d, b);
  if (o1 !== o2 && o3 !== o4) return true;
  return (
    (o1 === 0 && dentroDelRectangulo(a, b, c)) ||
    (o2 === 0 && dentroDelRectangulo(a, b, d)) ||
    (o3 === 0 && dentroDelRectangulo(c, d, a)) ||
    (o4 === 0 && dentroDelRectangulo(c, d, b))
  );
}

/** Los lados p→s y s→q van en línea recta pero de regreso (forman una "espina"). */
function seDevuelve(p: Coordenada, s: Coordenada, q: Coordenada): boolean {
  if (orientacion(p, s, q) !== 0) return false;
  return (p[0] - s[0]) * (q[0] - s[0]) + (p[1] - s[1]) * (q[1] - s[1]) > 0;
}
