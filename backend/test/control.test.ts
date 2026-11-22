import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.ts";
import type { Usuario, UsuarioActivo } from "../src/auth.ts";
import type { Control, Controles, FincaControl, FincaMuestreo, VisitaControl } from "../src/control.ts";
import type { Resultado } from "../src/correcciones.ts";
import type { Repo } from "../src/repo.ts";

const EXPORTADORA = "11111111-1111-4111-8111-111111111111";
const VINCULO = "22222222-2222-4222-8222-222222222222";
const FINCA = "33333333-3333-4333-8333-333333333333";

/** Visitas de control en memoria: registra las llamadas y responde lo configurado. */
class ControlesFalsa implements Controles {
  llamadas: unknown[][] = [];
  resultado: Resultado<null> = { ok: true, valor: null };
  async permitirVisitas(u: UsuarioActivo, id: string, permite: boolean) {
    this.llamadas.push(["permitirVisitas", id, permite]);
    return this.resultado;
  }
  async muestreo(_org: string, id: string): Promise<Resultado<{ permiteVisitas: boolean; fincas: FincaMuestreo[] }>> {
    this.llamadas.push(["muestreo", id]);
    return { ok: true, valor: { permiteVisitas: true, fincas: [] } };
  }
  async elegir(u: UsuarioActivo, id: string, fincaId: string, elegir: boolean) {
    this.llamadas.push(["elegir", id, fincaId, elegir]);
    return this.resultado;
  }
  async pendientes(org: string): Promise<FincaControl[]> {
    this.llamadas.push(["pendientes", org]);
    return [];
  }
  async registrar(u: UsuarioActivo, v: VisitaControl) {
    this.llamadas.push(["registrar", u.uid, v.fincaId, v.linderoCambio]);
    return this.resultado;
  }
  async controles(_org: string, id: string): Promise<Resultado<Control[]>> {
    this.llamadas.push(["controles", id]);
    return { ok: true, valor: [] };
  }
}

const usuarios: Record<string, Usuario> = {
  admin: { uid: "u-admin", email: "admin@exportadora.com", organizacionId: EXPORTADORA, rol: "admin" },
  tecnico: { uid: "u-tec", email: "tec@exportadora.com", organizacionId: EXPORTADORA, rol: "tecnico" },
};

function crearApp(conControles = true) {
  const controles = new ControlesFalsa();
  const app = buildApp({
    repo: {} as Repo,
    verificarToken: async (t) => usuarios[t] ?? null,
    identidad: {} as never,
    almacen: {} as never,
    satelite: null,
    verificarTarea: async () => false,
    controles: conControles ? controles : null,
  });
  const pedir = (method: "GET" | "POST" | "PUT" | "DELETE", url: string, token = "admin", payload?: object) =>
    app.inject({ method, url, headers: { authorization: `Bearer ${token}` }, payload });
  return { app, controles, pedir };
}

const visita = { id: "44444444-4444-4444-8444-444444444444", fincaId: FINCA, fecha: "2026-11-20T15:00:00.000Z", linderoCambio: false, nota: "Todo en orden" };

describe("rutas de visitas de control", () => {
  it("la cooperativa da permiso y la exportadora elige y quita fincas", async () => {
    const { controles, pedir } = crearApp();
    expect((await pedir("PUT", `/v1/clientes/${VINCULO}/visitas`, "admin", { permiteVisitas: true })).statusCode).toBe(204);
    expect((await pedir("GET", `/v1/proveedores/${VINCULO}/muestreo`)).statusCode).toBe(200);
    expect((await pedir("POST", `/v1/proveedores/${VINCULO}/muestreo`, "admin", { fincaId: FINCA })).statusCode).toBe(204);
    expect((await pedir("DELETE", `/v1/proveedores/${VINCULO}/muestreo/${FINCA}`)).statusCode).toBe(204);
    expect(controles.llamadas).toEqual([
      ["permitirVisitas", VINCULO, true],
      ["muestreo", VINCULO],
      ["elegir", VINCULO, FINCA, true],
      ["elegir", VINCULO, FINCA, false],
    ]);
  });

  it("el técnico ve sus fincas y registra visitas; no elige fincas ni da permisos", async () => {
    const { controles, pedir } = crearApp();
    expect((await pedir("GET", "/v1/control", "tecnico")).json()).toEqual({ fincas: [] });
    expect((await pedir("POST", "/v1/control/visitas", "tecnico", visita)).statusCode).toBe(204);
    expect(controles.llamadas.at(-1)).toEqual(["registrar", "u-tec", FINCA, false]);
    expect((await pedir("POST", `/v1/proveedores/${VINCULO}/muestreo`, "tecnico", { fincaId: FINCA })).statusCode).toBe(403);
    expect((await pedir("PUT", `/v1/clientes/${VINCULO}/visitas`, "tecnico", { permiteVisitas: true })).statusCode).toBe(403);
  });

  it("traduce los rechazos del servicio y valida los datos", async () => {
    const { controles, pedir } = crearApp();
    controles.resultado = { ok: false, status: 409, mensaje: "La cooperativa no ha permitido visitas de control." };
    const r = await pedir("POST", `/v1/proveedores/${VINCULO}/muestreo`, "admin", { fincaId: FINCA });
    expect(r.statusCode).toBe(409);
    expect(r.json().mensaje).toContain("no ha permitido");
    expect((await pedir("POST", "/v1/control/visitas", "tecnico", { ...visita, fecha: "2099-01-01T00:00:00.000Z" })).statusCode).toBe(422);
    expect((await pedir("GET", "/v1/proveedores/no-es-uuid/muestreo")).statusCode).toBe(404);
  });

  it("503 si las visitas de control no están disponibles", async () => {
    const { pedir } = crearApp(false);
    expect((await pedir("GET", "/v1/control", "tecnico")).statusCode).toBe(503);
  });
});
