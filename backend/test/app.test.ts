import { geoHash, type Coordenada } from "@trazacafe/eudr-eas-schemas";
import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.ts";
import { AccesoDenegado, aGeometria, type Repo } from "../src/repo.ts";
import type { LoteSync } from "../src/sync.ts";

const coords: Coordenada[] = [
  [-86.0023, 13.091],
  [-86.0013, 13.091],
  [-86.0013, 13.092],
  [-86.0023, 13.092],
];

const productor = {
  id: "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  nombre: "Productora de prueba",
  consentimientoFirmado: true,
};

const finca = {
  id: "3f2b8c1e-9a4d-4e7f-8b21-0c5d6e7f8a90",
  productorId: productor.id,
  nombre: "La Esperanza",
  coordenadas: coords,
  areaHa: 1.2,
  geoHash: geoHash(coords),
};

function crearApp() {
  const guardados: { cooperativaId: string; datos: LoteSync }[] = [];
  const repo: Repo = { guardarSync: async (cooperativaId, datos) => void guardados.push({ cooperativaId, datos }) };
  const app = buildApp({
    repo,
    verificarToken: async (t) => (t === "token-valido" ? { uid: "tecnico-1", cooperativaId: "coop-1" } : null),
  });
  return { app, guardados };
}

const sync = (app: ReturnType<typeof crearApp>["app"], payload: unknown, token = "token-valido") =>
  app.inject({ method: "POST", url: "/v1/sync", headers: { authorization: `Bearer ${token}` }, payload: payload as object });

describe("POST /v1/sync", () => {
  it("guarda productores y fincas válidos para la cooperativa del token", async () => {
    const { app, guardados } = crearApp();
    const res = await sync(app, { productores: [productor], fincas: [finca] });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ recibidos: { productores: 1, fincas: 1 } });
    expect(guardados[0].cooperativaId).toBe("coop-1");
  });

  it("rechaza sin token válido", async () => {
    const { app } = crearApp();
    expect((await sync(app, {}, "otro")).statusCode).toBe(401);
  });

  it("rechaza un geoHash que no coincide con las coordenadas", async () => {
    const { app, guardados } = crearApp();
    const alterada = { ...finca, coordenadas: [...coords.slice(0, 3), [-86.003, 13.093]] };
    const res = await sync(app, { fincas: [alterada] });
    expect(res.statusCode).toBe(422);
    expect(guardados).toHaveLength(0);
  });

  it("rechaza un punto único para fincas de 4 ha o más", async () => {
    const { app } = crearApp();
    const punto: Coordenada[] = [[-86.235, 13.6305]];
    const res = await sync(app, { fincas: [{ ...finca, coordenadas: punto, geoHash: geoHash(punto), areaHa: 5 }] });
    expect(res.statusCode).toBe(422);
  });

  it("responde 403 si el productor es de otra cooperativa", async () => {
    const app = buildApp({
      repo: { guardarSync: async () => { throw new AccesoDenegado("otra cooperativa"); } },
      verificarToken: async () => ({ uid: "tecnico-1", cooperativaId: "coop-1" }),
    });
    expect((await sync(app, { fincas: [finca] })).statusCode).toBe(403);
  });

  it("acepta fotos con hash válido", async () => {
    const { app, guardados } = crearApp();
    const foto = {
      id: "9b2e1f4a-6c3d-4f8e-a1b2-3c4d5e6f7a8b",
      entidadTipo: "productor",
      entidadId: productor.id,
      tipo: "consentimiento",
      sha256: `0x${"cd".repeat(32)}`,
    };
    const res = await sync(app, { productores: [productor], fotos: [foto] });
    expect(res.statusCode).toBe(200);
    expect(guardados[0].datos.fotos).toHaveLength(1);
  });

  it("rechaza fotos con hash mal formado", async () => {
    const { app } = crearApp();
    const foto = {
      id: "9b2e1f4a-6c3d-4f8e-a1b2-3c4d5e6f7a8b",
      entidadTipo: "finca",
      entidadId: finca.id,
      tipo: "finca",
      sha256: "abc",
    };
    expect((await sync(app, { fotos: [foto] })).statusCode).toBe(422);
  });

  it("rechaza productores sin consentimiento", async () => {
    const { app } = crearApp();
    const res = await sync(app, { productores: [{ ...productor, consentimientoFirmado: false }] });
    expect(res.statusCode).toBe(422);
  });
});

describe("aGeometria", () => {
  it("cierra el anillo del polígono", () => {
    const g = aGeometria(coords);
    expect(g.type).toBe("Polygon");
    const anillo = (g.coordinates as Coordenada[][])[0];
    expect(anillo.at(-1)).toEqual(anillo[0]);
  });

  it("usa Point para una sola coordenada", () => {
    expect(aGeometria([[-86.235, 13.6305]]).type).toBe("Point");
  });
});
