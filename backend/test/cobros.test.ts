import { describe, expect, it } from "vitest";
import {
  ajusteSchema,
  type ConsumoCobro,
  type ContratoCobro,
  contratoSchema,
  estadoDeCuenta,
  mesEnNicaragua,
} from "../src/cobros.ts";

const ORG = "11111111-1111-4111-8111-111111111111";

const contrato: ContratoCobro = {
  id: "c1",
  plan: "exportador",
  inicio: "2026-11-01",
  fin: "2027-10-31",
  cuotaUsd: 1500,
  contenedoresIncluidos: 2,
  precioContenedorUsd: 50,
  estado: "activo",
};

let n = 0;
const contenedor = (fecha: string, extra: Partial<ConsumoCobro> = {}): ConsumoCobro => ({
  id: `x${++n}`,
  tipo: "contenedor",
  fecha: new Date(fecha),
  contratoId: "c1",
  codigo: `EXP-${n}`,
  numeroContenedor: "CSQU3054383",
  cultivo: "cafe",
  kg: 19_200,
  precioUsd: 50,
  montoUsd: null,
  motivo: null,
  attestationUid: null,
  ...extra,
});
const ajuste = (fecha: string, montoUsd: number): ConsumoCobro => ({
  ...contenedor(fecha),
  tipo: "ajuste",
  codigo: null,
  numeroContenedor: null,
  cultivo: null,
  kg: null,
  precioUsd: null,
  montoUsd,
  motivo: "Cortesía de fundador",
});

describe("estadoDeCuenta", () => {
  it("el mes que empieza el contrato cobra la cuota y los contenedores van a la bolsa", () => {
    const e = estadoDeCuenta("2026-11", [contrato], [contenedor("2026-11-10T15:00:00Z")]);
    expect(e.contratos[0]).toMatchObject({ cuotaEsteMes: true, usados: 1, quedan: 1 });
    expect(e.contenedores.map((c) => [c.incluido, c.cobroUsd])).toEqual([[true, 0]]);
    expect(e.totalUsd).toBe(1500);
  });

  it("agotada la bolsa, cada contenedor se cobra al precio congelado al cerrar", () => {
    const consumos = [
      contenedor("2026-11-10T15:00:00Z"),
      contenedor("2026-11-20T15:00:00Z"),
      contenedor("2026-12-03T15:00:00Z"),
      contenedor("2026-12-15T15:00:00Z", { precioUsd: 45 }),
    ];
    const e = estadoDeCuenta("2026-12", [contrato], consumos);
    expect(e.contratos[0]).toMatchObject({ cuotaEsteMes: false, usados: 2, quedan: 0 });
    expect(e.contenedores.map((c) => [c.incluido, c.cobroUsd])).toEqual([
      [false, 50],
      [false, 45],
    ]);
    expect(e.totalUsd).toBe(95);
  });

  it("los meses se cuentan en hora de Nicaragua", () => {
    // 1 de diciembre a las 02:00 UTC es todavía 30 de noviembre en Managua.
    expect(mesEnNicaragua(new Date("2026-12-01T02:00:00Z"))).toBe("2026-11");
    const e = estadoDeCuenta("2026-11", [contrato], [contenedor("2026-12-01T02:00:00Z")]);
    expect(e.contenedores).toHaveLength(1);
  });

  it("los ajustes se suman con su signo, y lo de otros meses no", () => {
    const e = estadoDeCuenta("2026-12", [contrato], [ajuste("2026-12-02T15:00:00Z", -50), ajuste("2026-11-02T15:00:00Z", -999)]);
    expect(e.ajustes.map((a) => a.montoUsd)).toEqual([-50]);
    expect(e.totalUsd).toBe(-50);
  });

  it("un contenedor sin contrato se lista, pero no suma: hay que acordar su precio", () => {
    const e = estadoDeCuenta("2026-11", [], [contenedor("2026-11-10T15:00:00Z", { contratoId: null, precioUsd: null })]);
    expect(e.sinContrato).toBe(1);
    expect(e.contenedores[0].cobroUsd).toBeNull();
    expect(e.totalUsd).toBe(0);
  });

  it("solo por contenedor (sin cuota ni bolsa) o solo cuota (precio 0)", () => {
    const porUso = { ...contrato, cuotaUsd: 0, contenedoresIncluidos: 0 };
    expect(estadoDeCuenta("2026-11", [porUso], [contenedor("2026-11-10T15:00:00Z")]).totalUsd).toBe(50);
    const fijo = { ...contrato, contenedoresIncluidos: 0, precioContenedorUsd: 0 };
    expect(estadoDeCuenta("2026-11", [fijo], [contenedor("2026-11-10T15:00:00Z", { precioUsd: 0 })]).totalUsd).toBe(1500);
  });
});

describe("validación", () => {
  it("contrato: fechas en orden, plan y estado conocidos, montos sin negativos", () => {
    const base = { organizacionId: ORG, plan: "exportador", inicio: "2026-11-01", fin: "2027-10-31" };
    expect(contratoSchema.parse(base)).toMatchObject({ cuotaUsd: 0, contenedoresIncluidos: 0, estado: "prueba" });
    expect(contratoSchema.safeParse({ ...base, fin: "2026-10-01" }).success).toBe(false);
    expect(contratoSchema.safeParse({ ...base, plan: "gratis" }).success).toBe(false);
    expect(contratoSchema.safeParse({ ...base, precioContenedorUsd: -5 }).success).toBe(false);
    expect(contratoSchema.parse({ ...base, cuotaUsd: "1500.50" }).cuotaUsd).toBe(1500.5);
  });

  it("ajuste: con motivo y distinto de cero", () => {
    expect(ajusteSchema.safeParse({ organizacionId: ORG, montoUsd: -50, motivo: "Cortesía" }).success).toBe(true);
    expect(ajusteSchema.safeParse({ organizacionId: ORG, montoUsd: 0, motivo: "Cortesía" }).success).toBe(false);
    expect(ajusteSchema.safeParse({ organizacionId: ORG, montoUsd: -50, motivo: "" }).success).toBe(false);
  });
});
