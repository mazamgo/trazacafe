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
  geoHash: Hex;
  areaHa: number;
  deforestacionOK: boolean;
  fuenteChequeo: string;
  docsHash: Hex;
}

export function codificarFinca(d: DatosFinca): Hex {
  return codificar("Finca", [
    uuidABytes32(d.fincaId),
    d.geoHash,
    Math.round(d.areaHa * 100),
    d.deforestacionOK,
    d.fuenteChequeo,
    d.docsHash,
  ]);
}

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
