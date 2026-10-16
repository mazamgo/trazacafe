import { describe, expect, it } from "vitest";
import { GlobalForestWatch, revisar } from "../src/deforestacion.ts";

const poligono = {
  type: "Polygon" as const,
  coordinates: [[[-86.0023, 13.091], [-86.0013, 13.091], [-86.0013, 13.092], [-86.0023, 13.091]]],
};

describe("GlobalForestWatch", () => {
  it("consulta pérdida y alertas después de 2020 con la key y el polígono", async () => {
    const pedidos: { url: string; init: RequestInit }[] = [];
    const fetchFalso = (async (url: string, init: RequestInit) => {
      pedidos.push({ url, init });
      const data = url.includes("umd_tree_cover_loss") ? [{ ha: 0.02 }] : [{ alertas: 3, ha: 0.15 }];
      return new Response(JSON.stringify({ data, status: "success" }), { status: 200 });
    }) as unknown as typeof fetch;

    const gfw = new GlobalForestWatch("key-prueba", fetchFalso);
    const c = await revisar(gfw, { fincaId: "f1", version: 2, temporadaId: "t1", geometria: poligono });

    expect(pedidos.map((p) => p.url)).toEqual([
      "https://data-api.globalforestwatch.org/dataset/umd_tree_cover_loss/latest/query/json",
      "https://data-api.globalforestwatch.org/dataset/gfw_integrated_alerts/latest/query/json",
    ]);
    for (const p of pedidos) {
      expect((p.init.headers as Record<string, string>)["x-api-key"]).toBe("key-prueba");
      expect(JSON.parse(p.init.body as string).geometry).toEqual(poligono);
    }
    expect(JSON.parse(pedidos[0].init.body as string).sql).toContain("> 2020");
    expect(JSON.parse(pedidos[1].init.body as string).sql).toContain("'2020-12-31'");
    expect(c).toMatchObject({ alertas: 3, areaAfectadaHa: 0.15, resultado: "rojo", version: 2 });
  });

  it("si GFW responde con error, falla con el detalle", async () => {
    const fetchFalso = (async () => new Response("cuota excedida", { status: 429 })) as unknown as typeof fetch;
    await expect(new GlobalForestWatch("k", fetchFalso).consultar(poligono)).rejects.toThrow(/429/);
  });
});
