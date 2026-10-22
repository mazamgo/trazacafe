import { describe, expect, it } from "vitest";
import { GlobalForestWatch, MapasConAlertas, revisar, type FuenteSatelital, type Hallazgos } from "../src/deforestacion.ts";

const poligono = {
  type: "Polygon" as const,
  coordinates: [[[-86.0023, 13.091], [-86.0013, 13.091], [-86.0013, 13.092], [-86.0023, 13.091]]],
};
const finca = { fincaId: "f1", version: 2, temporadaId: "t1", geometria: poligono };

/** Respuesta de GFW con su forma real: ignora el alias de COUNT(*) y lo devuelve como "count". */
function gfwFalso(data: Record<string, unknown>, pedidos: { url: string; init: RequestInit }[] = []) {
  const fetchFalso = (async (url: string, init: RequestInit) => {
    pedidos.push({ url, init });
    return new Response(JSON.stringify({ data: [data], status: "success" }), { status: 200 });
  }) as unknown as typeof fetch;
  return new GlobalForestWatch("key-prueba", fetchFalso);
}

function mapasFalsos(haBosque2020: number, haPerdida = 0): FuenteSatelital {
  return {
    nombre: "JRC + Hansen",
    consultar: async (): Promise<Hallazgos> => ({ alertas: 0, haAlertas: 0, haPerdida, detalle: { haBosque2020 } }),
  };
}

describe("GlobalForestWatch", () => {
  it("consulta las alertas después de 2020 con la key y el polígono", async () => {
    const pedidos: { url: string; init: RequestInit }[] = [];
    const a = await gfwFalso({ count: 3, ha: 0.15 }, pedidos).alertas(poligono);

    expect(a).toEqual({ alertas: 3, ha: 0.15 });
    expect(pedidos.map((p) => p.url)).toEqual([
      "https://data-api.globalforestwatch.org/dataset/gfw_integrated_alerts/latest/query/json",
    ]);
    const { sql, geometry } = JSON.parse(pedidos[0].init.body as string);
    expect((pedidos[0].init.headers as Record<string, string>)["x-api-key"]).toBe("key-prueba");
    expect(geometry).toEqual(poligono);
    expect(sql).toContain("'2020-12-31'");
    // La API responde 422 con IN; las tres confianzas cuentan.
    expect(sql).not.toMatch(/\bIN\s*\(/i);
    for (const confianza of ["nominal", "high", "highest"]) expect(sql).toContain(`= '${confianza}'`);
  });

  it("sin alertas (ha en null) devuelve ceros", async () => {
    expect(await gfwFalso({ count: 0, ha: null }).alertas(poligono)).toEqual({ alertas: 0, ha: 0 });
  });

  it("si GFW responde con error, falla con el detalle", async () => {
    const fetchFalso = (async () => new Response("cuota excedida", { status: 429 })) as unknown as typeof fetch;
    await expect(new GlobalForestWatch("k", fetchFalso).alertas(poligono)).rejects.toThrow(/429/);
  });
});

describe("MapasConAlertas (modo combinado)", () => {
  it("con bosque en 2020 y alertas, la finca queda en amarillo, nunca en rojo", async () => {
    const fuente = new MapasConAlertas(mapasFalsos(3), gfwFalso({ count: 2839, ha: 33.97 }));
    const c = await revisar(fuente, finca);
    expect(c).toMatchObject({ resultado: "amarillo", alertas: 2839, areaAfectadaHa: 0, fuente: "JRC + Hansen + alertas integradas de GFW" });
    expect((c.detalle as Record<string, unknown>).alertasGfw).toEqual({ alertas: 2839, ha: 33.97 });
  });

  it("la pérdida confirmada de los mapas sigue poniendo rojo", async () => {
    const c = await revisar(new MapasConAlertas(mapasFalsos(3, 0.4), gfwFalso({ count: 0, ha: null })), finca);
    expect(c).toMatchObject({ resultado: "rojo", areaAfectadaHa: 0.4 });
  });

  it("sin bosque en 2020 según el JRC, no consulta GFW y queda en verde", async () => {
    const pedidos: { url: string; init: RequestInit }[] = [];
    const c = await revisar(new MapasConAlertas(mapasFalsos(0), gfwFalso({ count: 50, ha: 1 }, pedidos)), finca);
    expect(pedidos).toHaveLength(0);
    expect(c).toMatchObject({ resultado: "verde", alertas: 0 });
  });

  it("si GFW falla (key vencida), queda el resultado de los mapas con el error en el detalle", async () => {
    const fetchFalso = (async () => new Response("key vencida", { status: 401 })) as unknown as typeof fetch;
    const c = await revisar(new MapasConAlertas(mapasFalsos(3), new GlobalForestWatch("k", fetchFalso)), finca);
    expect(c).toMatchObject({ resultado: "verde", alertas: 0 });
    expect((c.detalle as { alertasGfw: { error: string } }).alertasGfw.error).toMatch(/401/);
  });

  it("si fallan los mapas, el chequeo falla (las alertas solas no deciden)", async () => {
    const mapas: FuenteSatelital = { nombre: "x", consultar: async () => Promise.reject(new Error("JRC caído")) };
    await expect(new MapasConAlertas(mapas, gfwFalso({ count: 1, ha: 1 })).consultar(poligono)).rejects.toThrow(/JRC/);
  });
});
