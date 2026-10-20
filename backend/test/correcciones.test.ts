import { describe, expect, it } from "vitest";
import {
  anulacionSchema,
  correccionEntregaSchema,
  correccionFincaSchema,
  correccionLoteSchema,
  correccionProductorSchema,
  correccionTemporadaSchema,
  diferencias,
  entregaSellada,
  normalizarCedula,
  sinPermiso,
  visitaSellada,
} from "../src/correcciones.ts";

const error = (r: { success: boolean; error?: { issues: { message: string }[] } }) => r.error?.issues.map((i) => i.message);

describe("motivo obligatorio en kg, áreas y fechas", () => {
  it("corregir kg o fecha de una entrega pide motivo; el estado no", () => {
    expect(error(correccionEntregaSchema.safeParse({ kg: 500 }))).toEqual(["Escribe el motivo de la corrección"]);
    expect(correccionEntregaSchema.safeParse({ kg: 500, motivo: "un cero de más" }).success).toBe(true);
    expect(correccionEntregaSchema.safeParse({ fecha: "2026-10-10T09:00:00-06:00" }).success).toBe(false);
    expect(correccionEntregaSchema.safeParse({ estado: "pergamino" }).success).toBe(true);
  });

  it("sin nada que corregir o con fecha futura, rechaza", () => {
    expect(error(correccionEntregaSchema.safeParse({ motivo: "nada" }))).toEqual(["Nada que corregir"]);
    const futura = new Date(Date.now() + 5 * 86400_000).toISOString();
    expect(correccionEntregaSchema.safeParse({ fecha: futura, motivo: "fecha" }).success).toBe(false);
  });

  it("anular siempre pide motivo de al menos 3 letras", () => {
    expect(anulacionSchema.safeParse({}).success).toBe(false);
    expect(anulacionSchema.safeParse({ motivo: "x" }).success).toBe(false);
    expect(anulacionSchema.safeParse({ motivo: "registrada dos veces" }).success).toBe(true);
  });

  it("peso de lote y área de finca piden motivo; nombres no", () => {
    expect(correccionLoteSchema.safeParse({ kg: 100 }).success).toBe(false);
    expect(correccionLoteSchema.safeParse({ codigo: "CAFE-002" }).success).toBe(true);
    expect(correccionFincaSchema.safeParse({ areaHa: 2.5 }).success).toBe(false);
    expect(correccionFincaSchema.safeParse({ nombre: "La Leonesa II" }).success).toBe(true);
    expect(error(correccionFincaSchema.safeParse({ areaHa: 30, motivo: "mal" }))).toEqual(["Fincas de 4 ha o más necesitan polígono (EUDR)"]);
    expect(correccionTemporadaSchema.safeParse({ fin: "2027-09-30" }).success).toBe(false);
    expect(correccionTemporadaSchema.safeParse({ nombre: "2026-27" }).success).toBe(true);
  });
});

describe("normalizarCedula (Nicaragua)", () => {
  it("acepta la cédula con o sin guiones y en minúsculas", () => {
    expect(normalizarCedula("001-010190-0001A")).toBe("001-010190-0001A");
    expect(normalizarCedula("0010101900001a")).toBe("001-010190-0001A");
    expect(normalizarCedula(" 281 251288 0000 y ")).toBe("281-251288-0000Y");
  });

  it("rechaza formatos o fechas imposibles", () => {
    expect(normalizarCedula("001-320190-0001A")).toBeNull();
    expect(normalizarCedula("001-011390-0001A")).toBeNull();
    expect(normalizarCedula("001-010190-00012")).toBeNull();
    expect(normalizarCedula("12345")).toBeNull();
    expect(correccionProductorSchema.safeParse({ cedula: "12345" }).success).toBe(false);
    expect(correccionProductorSchema.safeParse({ cedula: null }).success).toBe(true);
  });
});

describe("permisos y sellado", () => {
  it("el técnico corrige lo suyo; el administrador, todo", () => {
    expect(sinPermiso({ uid: "t1", rol: "tecnico" }, "t1")).toBeNull();
    expect(sinPermiso({ uid: "t1", rol: "tecnico" }, "t2")).toContain("Solo quien lo registró");
    expect(sinPermiso({ uid: "a1", rol: "admin" }, "t2")).toBeNull();
  });

  it("una entrega en un lote, firmada o anulada ya no se corrige", () => {
    const libre = { anulada: false, loteCodigo: null, atestada: false };
    expect(entregaSellada(libre)).toBeNull();
    expect(entregaSellada({ ...libre, loteCodigo: "CAFE-001" })).toContain("CAFE-001");
    expect(entregaSellada({ ...libre, atestada: true })).toContain("blockchain");
    expect(entregaSellada({ ...libre, anulada: true })).toContain("anulada");
  });

  it("una visita con lindero nuevo no se anula ni cambia de fecha", () => {
    expect(visitaSellada({ anulada: false, atestada: false, linderoCambio: false })).toBeNull();
    expect(visitaSellada({ anulada: false, atestada: false, linderoCambio: true })).toContain("lindero nuevo");
  });
});

describe("diferencias (historial)", () => {
  it("guarda solo lo que cambió, con su valor anterior", () => {
    const d = diferencias({ kg: 5000, estado: "uva", fecha: "2026-10-16T17:00:00.000Z" }, { kg: 500, estado: "uva", fecha: undefined });
    expect(d).toEqual({ antes: { kg: 5000 }, despues: { kg: 500 }, hay: true });
    expect(diferencias({ nombre: "A" }, { nombre: "A" }).hay).toBe(false);
    expect(diferencias({ cedula: null }, { cedula: "001-010190-0001A" }).antes).toEqual({ cedula: null });
  });
});
