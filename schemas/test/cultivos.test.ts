import { describe, expect, it } from "vitest";
import { convertirKg, cultivo, cultivos, estadoValido, ID_CULTIVOS, TODOS_LOS_ESTADOS } from "../src/index.ts";

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

  it("cada cultivo tiene un estado exportable (factor 1) y factores entre 0 y 1", () => {
    for (const c of cultivos) {
      expect(c.estados.filter((e) => e.factorExportable === 1)).toHaveLength(1);
      expect(c.estados.every((e) => e.factorExportable > 0 && e.factorExportable <= 1)).toBe(true);
      expect(c.maxKgExportableHa).toBeGreaterThan(0);
    }
  });

  it("convierte kg entre estados del mismo cultivo", () => {
    expect(convertirKg("cafe", 500, "uva", "pergamino")).toBeCloseTo(100);
    expect(convertirKg("cafe", 100, "pergamino", "oro")).toBeCloseTo(80);
    expect(convertirKg("cacao", 100, "baba", "seco")).toBeCloseTo(38);
    expect(() => convertirKg("cacao", 1, "uva", "seco")).toThrow();
  });
});
