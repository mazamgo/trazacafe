import { describe, expect, it } from "vitest";
import { cultivo, cultivos, estadoValido, ID_CULTIVOS, TODOS_LOS_ESTADOS } from "../src/index.ts";

describe("cultivos", () => {
  it("define café y cacao con su código HS para la DDS", () => {
    expect(ID_CULTIVOS).toEqual(["cafe", "cacao"]);
    expect(cultivo("cafe")?.codigoHS).toBe("0901");
    expect(cultivo("cacao")?.codigoHS).toBe("1801");
  });

  it("cada estado de entrega es válido solo en su cultivo", () => {
    expect(estadoValido("cafe", "pergamino")).toBe(true);
    expect(estadoValido("cacao", "baba")).toBe(true);
    expect(estadoValido("cafe", "baba")).toBe(false);
    expect(estadoValido("cacao", "uva")).toBe(false);
    expect(estadoValido("soya", "seco")).toBe(false);
  });

  it("los ids de estado no se repiten dentro de un cultivo y todos tienen nombre", () => {
    for (const c of cultivos) {
      const ids = c.estados.map((e) => e.id);
      expect(new Set(ids).size).toBe(ids.length);
      expect(c.estados.every((e) => e.nombre && e.corto)).toBe(true);
    }
    expect(TODOS_LOS_ESTADOS).toContain("fermentado");
  });
});
