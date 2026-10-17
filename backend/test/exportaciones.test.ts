import { describe, expect, it } from "vitest";
import { cambiosExportacionSchema, contenedorValido, evaluarExportacion, exportacionSchema } from "../src/exportaciones.ts";

const L1 = "11111111-1111-4111-8111-111111111111";
const L2 = "22222222-2222-4222-8222-222222222222";
const L3 = "33333333-3333-4333-8333-333333333333";

describe("contenedorValido (ISO 6346)", () => {
  it("acepta un número con dígito de control correcto y lo normaliza", () => {
    expect(contenedorValido("CSQU3054383")).toBe("CSQU3054383");
    expect(contenedorValido("csqu 305438-3")).toBe("CSQU3054383");
  });

  it("rechaza errores de tipeo y formatos que no son de contenedor", () => {
    expect(contenedorValido("CSQU3054384")).toBeNull();
    expect(contenedorValido("CSQU305438")).toBeNull();
    expect(contenedorValido("CSQA3054383")).toBeNull();
    expect(contenedorValido("1234567890A")).toBeNull();
  });
});

describe("exportacionSchema", () => {
  const base = { codigo: "EXP-001", comprador: "Tostador GmbH", destino: "Hamburgo, Alemania", lotes: [L1] };

  it("acepta un contenedor sin número todavía", () => {
    expect(exportacionSchema.safeParse(base).success).toBe(true);
  });

  it("normaliza el número de contenedor y rechaza uno inválido", () => {
    expect(exportacionSchema.parse({ ...base, contenedor: "csqu3054383" }).contenedor).toBe("CSQU3054383");
    const r = exportacionSchema.safeParse({ ...base, contenedor: "CSQU3054384" });
    expect(r.success).toBe(false);
    expect(r.error?.issues[0].message).toContain("dígito de control");
  });

  it("pide al menos un lote, sin repetir", () => {
    expect(exportacionSchema.safeParse({ ...base, lotes: [] }).success).toBe(false);
    expect(exportacionSchema.safeParse({ ...base, lotes: [L1, L1] }).success).toBe(false);
  });

  it("los cambios aceptan borrar el número (null) pero no un cuerpo vacío", () => {
    expect(cambiosExportacionSchema.parse({ contenedor: null })).toEqual({ contenedor: null });
    expect(cambiosExportacionSchema.parse({ ddsRef: " 26NIABC123 " })).toEqual({ ddsRef: "26NIABC123" });
    expect(cambiosExportacionSchema.safeParse({}).success).toBe(false);
  });
});

describe("evaluarExportacion", () => {
  const cafe1 = { id: L1, codigo: "CAFE-001", cultivo: "cafe", exportacionCodigo: null };
  const cafe2 = { id: L2, codigo: "CAFE-002", cultivo: "cafe", exportacionCodigo: null };

  it("con lotes libres de un mismo cultivo devuelve ese cultivo", () => {
    expect(evaluarExportacion([L1, L2], [cafe1, cafe2])).toEqual({ cultivo: "cafe", rechazos: [] });
  });

  it("rechaza lotes que ya van en otro contenedor o que no existen", () => {
    const ocupado = { ...cafe2, exportacionCodigo: "EXP-009" };
    const r = evaluarExportacion([L1, L2, L3], [cafe1, ocupado]);
    expect(r.cultivo).toBeNull();
    expect(r.rechazos).toEqual([
      { loteId: L2, motivo: "CAFE-002 ya está en el contenedor EXP-009" },
      { loteId: L3, motivo: "No existe o es de otra organización" },
    ]);
  });

  it("no mezcla café y cacao en un contenedor", () => {
    const cacao = { id: L3, codigo: "CACAO-001", cultivo: "cacao", exportacionCodigo: null };
    const r = evaluarExportacion([L1, L3], [cafe1, cacao]);
    expect(r.cultivo).toBeNull();
    expect(r.rechazos[0].motivo).toContain("un solo cultivo");
  });
});
