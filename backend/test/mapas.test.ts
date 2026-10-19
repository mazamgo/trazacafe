import { describe, expect, it } from "vitest";
import { clasificar } from "../src/deforestacion.ts";
import { analizar, dentro, MapasPublicos, type Mapa, type Ventana } from "../src/mapas.ts";

/**
 * Mapa sintético: una cuadrícula global con origen (-90, 20) como la de
 * Hansen, cuyo valor en cada píxel lo decide [valor(lon, lat)].
 */
function mapa(res: number, valor: (lon: number, lat: number) => number): Mapa {
  const ox = -90;
  const oy = 20;
  return {
    async leer([oeste, sur, este, norte]): Promise<Ventana> {
      const x0 = Math.floor((oeste - ox) / res);
      const y0 = Math.floor((oy - norte) / res);
      const x1 = Math.ceil((este - ox) / res);
      const y1 = Math.ceil((oy - sur) / res);
      const ancho = x1 - x0;
      const alto = y1 - y0;
      const datos = new Uint8Array(ancho * alto);
      for (let f = 0; f < alto; f++) {
        for (let c = 0; c < ancho; c++) {
          datos[f * ancho + c] = valor(ox + (x0 + c + 0.5) * res, oy - (y0 + f + 0.5) * res);
        }
      }
      return { datos, ancho, alto, oeste: ox + x0 * res, norte: oy - y0 * res, res };
    },
  };
}

// Cuadrado de 0.01° en Jinotega: 1.08 km × 1.11 km ≈ 120.4 ha.
const cuadrado = {
  type: "Polygon" as const,
  coordinates: [[[-86.01, 13.09], [-86.0, 13.09], [-86.0, 13.1], [-86.01, 13.1], [-86.01, 13.09]]],
};
const RES_JRC = 1 / 12000;
const RES_HANSEN = 0.00025;

describe("dentro", () => {
  it("respeta los huecos y los multipolígonos", () => {
    const conHueco = {
      type: "Polygon" as const,
      coordinates: [
        [[0, 0], [10, 0], [10, 10], [0, 10], [0, 0]],
        [[4, 4], [6, 4], [6, 6], [4, 6], [4, 4]],
      ],
    };
    expect(dentro(1, 1, conHueco)).toBe(true);
    expect(dentro(5, 5, conHueco)).toBe(false);
    expect(dentro(11, 1, conHueco)).toBe(false);
    const multi = { type: "MultiPolygon" as const, coordinates: [conHueco.coordinates, [[[20, 0], [21, 0], [21, 1], [20, 1], [20, 0]]]] };
    expect(dentro(20.5, 0.5, multi)).toBe(true);
  });
});

describe("analizar", () => {
  it("sin pérdida después de 2020 da 0 ha; mide el área y el bosque de 2020", async () => {
    const r = await analizar(cuadrado, mapa(RES_JRC, () => 1), mapa(RES_HANSEN, () => 12));
    expect(r.haAnalizadas).toBeGreaterThan(119);
    expect(r.haAnalizadas).toBeLessThan(122);
    expect(r.haBosque2020).toBe(r.haAnalizadas);
    expect(r.haPerdidaEnBosque2020).toBe(0);
  });

  it("cuenta solo la pérdida de 2021+ sobre lo que era bosque en 2020, y la separa por año", async () => {
    // Bosque en la mitad oeste; pérdida 2022 en la franja sur de toda la finca.
    const bosque = mapa(RES_JRC, (lon) => (lon < -86.005 ? 1 : 0));
    const perdida = mapa(RES_HANSEN, (_lon, lat) => (lat < 13.091 ? 22 : 0));
    const r = await analizar(cuadrado, bosque, perdida);
    // Franja de 0.001° de alto: ~1.08 km × 110 m ≈ 11.9 ha; la mitad era bosque.
    expect(r.haPerdidaEnBosque2020).toBeGreaterThan(5);
    expect(r.haPerdidaEnBosque2020).toBeLessThan(7);
    expect(r.haPerdidaFueraDeBosque2020).toBeGreaterThan(5);
    expect(Object.keys(r.perdidaPorAnio)).toEqual(["2022"]);
    expect(r.haBosque2020).toBeGreaterThan(55);
  });

  it("la pérdida de 2020 o antes no cuenta (corte del EUDR)", async () => {
    const r = await analizar(cuadrado, mapa(RES_JRC, () => 1), mapa(RES_HANSEN, () => 20));
    expect(r.haPerdidaEnBosque2020).toBe(0);
  });
});

describe("MapasPublicos", () => {
  it("una finca con un claro de bosque de 2023 sale en rojo", async () => {
    const fuente = new MapasPublicos(
      mapa(RES_JRC, () => 1),
      mapa(RES_HANSEN, (lon, lat) => (Math.abs(lon + 86.005) < 0.0005 && Math.abs(lat - 13.095) < 0.0005 ? 23 : 0)),
    );
    const h = await fuente.consultar(cuadrado);
    expect(h.haPerdida).toBeGreaterThan(0.5);
    expect(clasificar(h)).toBe("rojo");
    expect(h.detalle).toMatchObject({ corte: "2020-12-31", perdidaPorAnio: { "2023": h.haPerdida } });
  });

  it("una finca de café sin bosque en 2020 y sin pérdida sale en verde", async () => {
    const h = await new MapasPublicos(mapa(RES_JRC, () => 0), mapa(RES_HANSEN, () => 0)).consultar(cuadrado);
    expect(clasificar(h)).toBe("verde");
  });

  it("un punto pequeñísimo sin píxeles da error en vez de verde", async () => {
    const mini = { type: "Polygon" as const, coordinates: [[[-86.00001, 13.09001], [-86.000005, 13.09001], [-86.000005, 13.090015], [-86.00001, 13.09001]]] };
    await expect(new MapasPublicos(mapa(RES_JRC, () => 1), mapa(RES_HANSEN, () => 0)).consultar(mini)).rejects.toThrow("demasiado pequeño");
  });
});
