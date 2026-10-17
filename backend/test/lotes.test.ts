import { describe, expect, it } from "vitest";
import { evaluarLote, motivoExclusion, type EntregaCandidata, type LoteNuevo } from "../src/lotes.ts";

const T = "11111111-1111-4111-8111-111111111111";
const OTRA_T = "22222222-2222-4222-8222-222222222222";

let n = 0;
function entrega(p: Partial<EntregaCandidata> = {}): EntregaCandidata {
  n++;
  return {
    id: `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`,
    fincaId: "f1",
    fincaNombre: "La Leonesa",
    productorNombre: "Productora",
    cultivo: "cafe",
    temporadaId: T,
    kg: 500,
    estado: "uva",
    fecha: "2026-10-16T17:00:00.000Z",
    deforestacion: "verde",
    verificada: true,
    areaOficialHa: 4,
    kgExportablesFincaTemporada: 80,
    loteCodigo: null,
    ...p,
  };
}

function lote(entregas: EntregaCandidata[], p: Partial<LoteNuevo> = {}): LoteNuevo {
  return { codigo: "L-1", cultivo: "cafe", temporadaId: T, estado: "pergamino", kg: 100, entregas: entregas.map((e) => e.id), ...p };
}

describe("motivoExclusion (reglas EUDR del lote)", () => {
  it("acepta una entrega de una finca verificada y sin deforestación", () => {
    expect(motivoExclusion(entrega(), "cafe", T)).toBeNull();
  });

  it("rechaza fincas en rojo, sin visita, de otro cultivo, de otra temporada o ya en un lote", () => {
    expect(motivoExclusion(entrega({ deforestacion: "rojo" }), "cafe", T)).toMatch(/pérdida de bosque/);
    expect(motivoExclusion(entrega({ verificada: false }), "cafe", T)).toMatch(/visita/);
    expect(motivoExclusion(entrega({ cultivo: "cacao", estado: "seco" }), "cafe", T)).toMatch(/cacao/);
    expect(motivoExclusion(entrega({ temporadaId: OTRA_T }), "cafe", T)).toMatch(/otra temporada/);
    expect(motivoExclusion(entrega({ temporadaId: null }), "cafe", T)).toMatch(/otra temporada/);
    expect(motivoExclusion(entrega({ loteCodigo: "L-9" }), "cafe", T)).toMatch(/L-9/);
  });

  it("una finca pendiente o amarilla puede entrar (solo es aviso)", () => {
    expect(motivoExclusion(entrega({ deforestacion: "pendiente" }), "cafe", T)).toBeNull();
    expect(motivoExclusion(entrega({ deforestacion: "amarillo" }), "cafe", T)).toBeNull();
  });
});

describe("evaluarLote", () => {
  it("500 kg de uva rinden unos 100 kg de pergamino: sin avisos", () => {
    const e = entrega();
    const r = evaluarLote(lote([e], { kg: 105 }), [e]);
    expect(r.rechazos).toEqual([]);
    expect(r.kgEsperados).toBeCloseTo(100);
    expect(r.avisos).toEqual([]);
  });

  it("avisa si el lote pesa más de lo que rinden sus entregas (más del 10 %)", () => {
    const e = entrega();
    const r = evaluarLote(lote([e], { kg: 150 }), [e]);
    expect(r.avisos.map((a) => a.codigo)).toEqual(["volumen"]);
    expect(r.avisos[0].mensaje).toContain("150 kg");
    expect(r.avisos[0].mensaje).toContain("100 kg de pergamino");
  });

  it("avisa si una finca rinde más por hectárea de lo razonable", () => {
    // 1 ha con 3,000 kg de oro en la temporada (máximo café: 2,500 kg/ha).
    const e = entrega({ areaOficialHa: 1, kgExportablesFincaTemporada: 3000 });
    const r = evaluarLote(lote([e]), [e]);
    expect(r.avisos.map((a) => a.codigo)).toEqual(["rendimiento"]);
    expect(r.avisos[0].mensaje).toContain("La Leonesa");
  });

  it("avisa cuántas fincas no tienen chequeo satelital verde", () => {
    const a = entrega({ fincaId: "f1", deforestacion: "pendiente" });
    const b = entrega({ fincaId: "f2", fincaNombre: "XXX", deforestacion: "verde" });
    const r = evaluarLote(lote([a, b], { kg: 200 }), [a, b]);
    expect(r.avisos.map((x) => x.codigo)).toEqual(["satelite"]);
    expect(r.avisos[0].mensaje).toMatch(/^1 de 2 fincas/);
  });

  it("rechaza el lote si alguna entrega no cumple o no existe, diciendo cuál y por qué", () => {
    const buena = entrega();
    const roja = entrega({ deforestacion: "rojo" });
    const inexistente = "99999999-9999-4999-8999-999999999999";
    const r = evaluarLote({ ...lote([buena, roja]), entregas: [buena.id, roja.id, inexistente] }, [buena, roja]);
    expect(r.rechazos).toEqual([
      { entregaId: roja.id, motivo: expect.stringMatching(/pérdida de bosque/) },
      { entregaId: inexistente, motivo: "No existe o es de otra organización" },
    ]);
  });

  it("convierte entregas de cacao en baba y fermentado a cacao seco", () => {
    const baba = entrega({ cultivo: "cacao", estado: "baba", kg: 100 });
    const ferm = entrega({ cultivo: "cacao", estado: "fermentado", kg: 100 });
    const r = evaluarLote(lote([baba, ferm], { cultivo: "cacao", estado: "seco", kg: 83 }), [baba, ferm]);
    expect(r.kgEsperados).toBeCloseTo(38 + 45);
    expect(r.avisos).toEqual([]);
  });
});
