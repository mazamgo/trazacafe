import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.ts";
import type { Usuario } from "../src/auth.ts";
import type { Repo } from "../src/repo.ts";
import { armarReporte, csvReporte, type DatosReporte, type FincaReporte, type Reportes } from "../src/reportes.ts";

const ORG = "11111111-1111-4111-8111-111111111111";
const T = "33333333-3333-4333-8333-333333333333";

let n = 0;
const finca = (p: Partial<FincaReporte> = {}): FincaReporte => ({
  id: `f${++n}`,
  nombre: `Finca ${n}`,
  productorId: `p${n}`,
  productorNombre: `Productor ${n}`,
  comunidad: "El Cuá",
  cultivo: "cafe",
  geometria: { type: "Point", coordinates: [-85.7, 13.4] },
  areaOficialHa: 2,
  deforestacion: "verde",
  ultimoChequeo: "2026-11-01T12:00:00.000Z",
  fuente: "jrc-hansen",
  areaAfectadaHa: 0,
  conVisita: true,
  kgEntregados: 100,
  ...p,
});

const datos = (p: Partial<DatosReporte> = {}): DatosReporte => ({
  temporada: { id: T, nombre: "2026/27", inicio: "2026-10-01", fin: "2027-09-30", cultivo: null },
  fincas: [
    finca({ nombre: "Las Brisas" }),
    finca({ nombre: "El Roble", deforestacion: "rojo", conVisita: false }),
    finca({ nombre: "Buena Vista", deforestacion: "amarillo", productorId: "p1" }),
    finca({ nombre: "La Cumbre", deforestacion: "pendiente", ultimoChequeo: null, fuente: null, areaAfectadaHa: null }),
  ],
  entregas: [
    { cultivo: "cafe", estado: "uva", enLote: true, kg: 500, entregas: 2 },
    { cultivo: "cafe", estado: "uva", enLote: false, kg: 100, entregas: 1 },
    { cultivo: "cafe", estado: "pergamino", enLote: false, kg: 80, entregas: 1 },
  ],
  lotes: { abiertos: 1, cerrados: 2, vendidos: 1, enContenedor: 1, kg: 116 },
  visitas: [{ email: "tecnico@coop.org", visitas: 3 }, { email: null, visitas: 1 }],
  ...p,
});

describe("armarReporte", () => {
  it("cuenta productores, fincas, visitas y estado satelital", () => {
    const r = armarReporte(datos());
    expect(r.resumen).toMatchObject({ productores: 3, fincas: 4, areaOficialHa: 8, conVisita: 3, porcentajeVisita: 75, verdes: 1, porcentajeVerde: 25 });
    expect(r.satelite).toEqual({ verde: 1, amarillo: 1, rojo: 1, pendiente: 1 });
  });

  it("las alertas van de la más grave a la menos grave y sin las verdes", () => {
    expect(armarReporte(datos()).alertas.map((f) => f.nombre)).toEqual(["El Roble", "Buena Vista", "La Cumbre"]);
  });

  it("lista las fincas sin visita", () => {
    expect(armarReporte(datos()).sinVisita).toEqual([{ id: expect.any(String), nombre: "El Roble", productorNombre: expect.any(String), comunidad: "El Cuá" }]);
  });

  it("suma los kg por cultivo y estado, en lotes y libres, con su equivalente en oro", () => {
    const r = armarReporte(datos());
    expect(r.resumen).toMatchObject({ kgEntregados: 680, entregas: 4 });
    const uva = r.kg.find((k) => k.estado === "uva")!;
    expect(uva).toMatchObject({ kg: 600, kgEnLotes: 500, kgLibres: 100, entregas: 3, estadoExportable: "oro" });
    expect(uva.kgExportables).toBeCloseTo(96);
    expect(r.kg.find((k) => k.estado === "pergamino")!.kgExportables).toBeCloseTo(64);
  });

  it("sin fincas los porcentajes son cero", () => {
    expect(armarReporte(datos({ fincas: [] })).resumen).toMatchObject({ fincas: 0, porcentajeVisita: 0, porcentajeVerde: 0 });
  });
});

describe("csvReporte", () => {
  it("lleva BOM, encabezados, una fila por finca y comillas donde hace falta", () => {
    const csv = csvReporte(datos({ fincas: [finca({ nombre: 'La "Esperanza", lote 2', deforestacion: "pendiente", ultimoChequeo: null, conVisita: false })] }));
    expect(csv.startsWith("﻿Productor,Comunidad,Finca,Cultivo,Área oficial (ha),Estado satelital")).toBe(true);
    const lineas = csv.trimEnd().split("\r\n");
    expect(lineas).toHaveLength(2);
    expect(lineas[1]).toContain('"La ""Esperanza"", lote 2"');
    expect(lineas[1]).toContain(",Café,2,Sin chequeo,,No,100");
  });
});

describe("rutas de reportes", () => {
  const usuarios: Record<string, Usuario> = {
    admin: { uid: "u-admin", email: "admin@coop.org", organizacionId: ORG, rol: "admin" },
    tecnico: { uid: "u-tec", email: "tec@coop.org", organizacionId: ORG, rol: "tecnico" },
  };
  const reportes: Reportes = { datos: async (org, t) => (org === ORG && t === T ? datos() : null) };
  const app = buildApp({
    repo: {} as Repo,
    verificarToken: async (t) => usuarios[t] ?? null,
    identidad: {} as never,
    almacen: {} as never,
    satelite: null,
    verificarTarea: async () => false,
    reportes,
  });
  const pedir = (url: string, token = "admin") => app.inject({ method: "GET", url, headers: { authorization: `Bearer ${token}` } });

  it("el administrador ve el reporte de su temporada", async () => {
    const res = await pedir(`/v1/reportes?temporadaId=${T}`);
    expect(res.statusCode).toBe(200);
    expect(res.json().resumen.fincas).toBe(4);
  });

  it("el CSV se descarga como archivo", async () => {
    const res = await pedir(`/v1/reportes/csv?temporadaId=${T}`);
    expect(res.statusCode).toBe(200);
    expect(res.headers["content-type"]).toContain("text/csv");
    expect(res.headers["content-disposition"]).toContain('filename="Reporte-');
    expect(res.body.split("\r\n")).toHaveLength(6);
  });

  it("es solo para administradores y de temporadas propias", async () => {
    expect((await pedir(`/v1/reportes?temporadaId=${T}`, "tecnico")).statusCode).toBe(403);
    expect((await pedir(`/v1/reportes?temporadaId=${crypto.randomUUID()}`)).statusCode).toBe(404);
    expect((await pedir("/v1/reportes?temporadaId=no-es-uuid")).statusCode).toBe(404);
    expect((await pedir("/v1/reportes")).statusCode).toBe(404);
  });
});
