import { decodeAbiParameters, parseAbiParameters } from "viem";
import { describe, expect, it } from "vitest";
import vectores from "../test-vectors.json" with { type: "json" };
import {
  codificarFinca,
  coordenadasCanonicas,
  esquemas,
  geoHash,
  problemaPoligono,
  schemaUid,
  uuidABytes32,
  type Coordenada,
} from "../src/index.ts";

describe("esquemas EAS", () => {
  it("define la finca, su verificación y los pasos de la cadena de custodia", () => {
    expect(esquemas.map((e) => e.nombre)).toEqual(["Finca", "Verificacion", "Entrega", "Lote", "Exportacion"]);
  });

  it("calcula UIDs distintos y estables", () => {
    const uids = esquemas.map((e) => schemaUid(e.schema, e.revocable));
    expect(new Set(uids).size).toBe(esquemas.length);
    expect(uids.every((u) => /^0x[0-9a-f]{64}$/.test(u))).toBe(true);
  });
});

describe("codificarFinca", () => {
  it("codifica y decodifica los mismos valores", () => {
    const datos = {
      fincaId: "3f2b8c1e-9a4d-4e7f-8b21-0c5d6e7f8a90",
      version: 2,
      geoHash: geoHash(vectores[0].coords as Coordenada[]),
      areaHa: 1.2345,
      deforestacionOK: true,
      fuenteChequeo: "JRC-GFC2020+GFW",
      docsHash: `0x${"ab".repeat(32)}` as const,
    };
    const decodificado = decodeAbiParameters(
      parseAbiParameters(esquemas[0].schema),
      codificarFinca(datos),
    );
    expect(decodificado[0]).toBe(uuidABytes32(datos.fincaId));
    expect(decodificado[1]).toBe(2);
    expect(decodificado[2]).toBe(datos.geoHash);
    expect(decodificado[3]).toBe(123);
    expect(decodificado[4]).toBe(true);
    expect(decodificado[5]).toBe("JRC-GFC2020+GFW");
  });

  it("rechaza IDs que no son UUID", () => {
    expect(() => uuidABytes32("finca-1")).toThrow();
  });
});

describe("geoHash y validez del polígono", () => {
  for (const v of vectores) {
    it(v.nombre, () => {
      const coords = v.coords as Coordenada[];
      expect(coordenadasCanonicas(coords)).toBe(v.canonico);
      expect(geoHash(coords)).toBe(v.geoHash);
      expect(problemaPoligono(coords)).toBe(v.problema);
    });
  }
});
