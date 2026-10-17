import { decodeAbiParameters, parseAbiParameters } from "viem";
import { describe, expect, it } from "vitest";
import vectores from "../test-vectors.json" with { type: "json" };
import {
  codificarFinca,
  coordenadasCanonicas,
  esquemas,
  geoHash,
  hashDeHashes,
  kgX100,
  problemaPoligono,
  schemaUid,
  uuidABytes32,
  type Coordenada,
} from "../src/index.ts";

describe("esquemas EAS", () => {
  it("define la finca, su verificación y los pasos de la cadena de custodia", () => {
    expect(esquemas.map((e) => e.nombre)).toEqual(["Finca", "Chequeo", "Verificacion", "Entrega", "Lote", "Exportacion"]);
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
      cultivo: "cacao",
      geoHash: geoHash(vectores[0].coords as Coordenada[]),
      areaHa: 1.2345,
      docsHash: `0x${"ab".repeat(32)}` as const,
    };
    const decodificado = decodeAbiParameters(
      parseAbiParameters(esquemas[0].schema),
      codificarFinca(datos),
    );
    expect(decodificado[0]).toBe(uuidABytes32(datos.fincaId));
    expect(decodificado[1]).toBe(2);
    expect(decodificado[2]).toBe("cacao");
    expect(decodificado[3]).toBe(datos.geoHash);
    expect(decodificado[4]).toBe(123);
    expect(decodificado[5]).toBe(datos.docsHash);
  });

  it("los esquemas no llevan datos personales: solo ids, hashes, cantidades y textos de catálogo", () => {
    const todos = esquemas.map((e) => e.schema).join(",");
    for (const prohibido of ["nombre", "cedula", "productor", "comunidad", "comprador"]) {
      expect(todos.toLowerCase()).not.toContain(prohibido);
    }
  });

  it("rechaza IDs que no son UUID", () => {
    expect(() => uuidABytes32("finca-1")).toThrow();
  });
});

describe("hashDeHashes y kgX100", () => {
  it("no depende del orden ni de mayúsculas y vale cero sin hashes", () => {
    expect(hashDeHashes(["0xBB", "0xaa"])).toBe(hashDeHashes(["0xaa", "0xbb"]));
    expect(hashDeHashes([])).toBe(`0x${"0".repeat(64)}`);
  });

  it("guarda los kg con dos decimales", () => {
    expect(kgX100(345.5)).toBe(34550);
    expect(kgX100(0.015)).toBe(2);
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
