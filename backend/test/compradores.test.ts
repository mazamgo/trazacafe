import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.ts";
import type { Usuario, UsuarioActivo } from "../src/auth.ts";
import {
  correoAlertas,
  paqueteParaComprador,
  type AlertaComprador,
  type Comprador,
  type Compradores,
  type ContenedorComprado,
} from "../src/compradores.ts";
import type { Resultado } from "../src/correcciones.ts";
import type { Repo } from "../src/repo.ts";
import { paqueteDePrueba } from "./datos-paquete.ts";

const EXPORTADORA = "11111111-1111-4111-8111-111111111111";
const IMPORTADOR = "55555555-5555-4555-8555-555555555555";
const CONTENEDOR = "66666666-6666-4666-8666-666666666666";
const COMPRADOR = "77777777-7777-4777-8777-777777777777";

class CompradoresFalsa implements Compradores {
  llamadas: unknown[][] = [];
  resultado: Resultado<null> = { ok: true, valor: null };
  async lista(): Promise<Comprador[]> {
    return [];
  }
  async invitar(u: UsuarioActivo, email: string): Promise<Resultado<Comprador>> {
    this.llamadas.push(["invitar", email]);
    return { ok: true, valor: { id: COMPRADOR, soy: "exportadora", organizacion: { id: IMPORTADOR, nombre: "Rösterei GmbH" }, estado: "pendiente", invitadoEn: "2026-11-22T00:00:00.000Z", contenedores: 0 } };
  }
  async responder(_u: UsuarioActivo, id: string, aceptar: boolean) {
    this.llamadas.push(["responder", id, aceptar]);
    return this.resultado;
  }
  async terminar(_u: UsuarioActivo, id: string) {
    this.llamadas.push(["terminar", id]);
    return this.resultado;
  }
  async asignar(_u: UsuarioActivo, id: string, compradorId: string | null) {
    this.llamadas.push(["asignar", id, compradorId]);
    return this.resultado;
  }
  async contenedores(): Promise<ContenedorComprado[]> {
    return [];
  }
  async exportadoraDe(importador: string, id: string) {
    return importador === IMPORTADOR && id === CONTENEDOR ? EXPORTADORA : null;
  }
  async anotarDds(_u: UsuarioActivo, id: string, dds: string) {
    this.llamadas.push(["dds", id, dds]);
    return this.resultado;
  }
  async alertas(): Promise<AlertaComprador[]> {
    return [];
  }
  async registrarAlertas() {
    return 0;
  }
  async alertasPorAvisar() {
    return [];
  }
  async marcarAvisadas() {}
}

const usuarios: Record<string, Usuario> = {
  exportadora: { uid: "u-exp", email: "admin@exportadora.com", organizacionId: EXPORTADORA, rol: "admin" },
  importador: { uid: "u-imp", email: "einkauf@roesterei.de", organizacionId: IMPORTADOR, rol: "admin" },
  tecnicoImp: { uid: "u-imp2", email: "x@roesterei.de", organizacionId: IMPORTADOR, rol: "tecnico" },
};

function crearApp() {
  const compradores = new CompradoresFalsa();
  const repo = { paqueteExportacion: async (org: string) => (org === EXPORTADORA ? paqueteDePrueba({ estado: "cerrada" }) : null) } as unknown as Repo;
  const app = buildApp({
    repo,
    verificarToken: async (t) => usuarios[t] ?? null,
    identidad: {} as never,
    almacen: {} as never,
    satelite: null,
    verificarTarea: async () => false,
    compradores,
  });
  const pedir = (method: "GET" | "POST" | "PUT" | "DELETE", url: string, token: string, payload?: object) =>
    app.inject({ method, url, headers: { authorization: `Bearer ${token}` }, payload });
  return { compradores, pedir };
}

describe("paquete y correo del importador", () => {
  it("el paquete no lleva nombres de productores ni de fincas", () => {
    const p = paqueteParaComprador(paqueteDePrueba());
    expect(p.fincas.map((f) => [f.nombre, f.productorNombre])).toEqual([["Finca F1", null], ["Finca F2", null]]);
    expect(p.fincas[0].geometria.type).toBe("Polygon");
  });

  it("el correo lista cada alerta y dice si hay rojo", () => {
    const m = correoAlertas([
      { id: 1, contenedor: "CSQU3054383", codigo: "EXP-1", finca: "Finca 3F2A", resultado: "rojo", detectadaEn: "2026-11-20T10:00:00.000Z" },
    ]);
    expect(m.asunto).toContain("1 alerta satelital");
    expect(m.texto).toContain("pérdida de bosque");
    expect(m.texto).toContain("- CSQU3054383 (EXP-1): Finca 3F2A, rojo, 2026-11-20");
  });
});

describe("rutas del portal del importador", () => {
  it("la exportadora invita, asigna y libera; el importador responde", async () => {
    const { compradores, pedir } = crearApp();
    expect((await pedir("POST", "/v1/compradores", "exportadora", { email: "Einkauf@Roesterei.de" })).statusCode).toBe(201);
    expect((await pedir("POST", `/v1/compradores/${COMPRADOR}/aceptar`, "importador")).statusCode).toBe(204);
    expect((await pedir("PUT", `/v1/exportaciones/${CONTENEDOR}/comprador`, "exportadora", { compradorId: COMPRADOR })).statusCode).toBe(204);
    expect((await pedir("DELETE", `/v1/exportaciones/${CONTENEDOR}/comprador`, "exportadora")).statusCode).toBe(204);
    expect(compradores.llamadas).toEqual([
      ["invitar", "einkauf@roesterei.de"],
      ["responder", COMPRADOR, true],
      ["asignar", CONTENEDOR, COMPRADOR],
      ["asignar", CONTENEDOR, null],
    ]);
  });

  it("el importador ve y descarga solo lo comprado, sin nombres", async () => {
    const { pedir } = crearApp();
    const detalle = await pedir("GET", `/v1/comprador/contenedores/${CONTENEDOR}`, "tecnicoImp");
    expect(detalle.statusCode).toBe(200);
    expect(detalle.body).not.toContain("Ana Pérez");
    expect(detalle.body).not.toContain("La Leonesa");
    const geo = await pedir("GET", `/v1/comprador/contenedores/${CONTENEDOR}/geojson`, "importador");
    expect(geo.json().features[0].properties.ProducerName).toBeUndefined();
    expect((await pedir("GET", `/v1/comprador/contenedores/${CONTENEDOR}/pdf`, "importador")).headers["content-type"]).toContain("pdf");
    expect((await pedir("GET", `/v1/comprador/contenedores/${crypto.randomUUID()}`, "importador")).statusCode).toBe(404);
    expect((await pedir("GET", `/v1/comprador/contenedores/${CONTENEDOR}`, "exportadora")).statusCode).toBe(404);
  });

  it("anota la DDS solo un administrador del importador", async () => {
    const { compradores, pedir } = crearApp();
    expect((await pedir("PUT", `/v1/comprador/contenedores/${CONTENEDOR}/dds`, "importador", { ddsRef: "25DEHH1234567" })).statusCode).toBe(204);
    expect(compradores.llamadas.at(-1)).toEqual(["dds", CONTENEDOR, "25DEHH1234567"]);
    expect((await pedir("PUT", `/v1/comprador/contenedores/${CONTENEDOR}/dds`, "tecnicoImp", { ddsRef: "X" })).statusCode).toBe(403);
  });
});
