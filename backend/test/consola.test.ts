import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.ts";
import type { Usuario } from "../src/auth.ts";
import type { Consola, OrganizacionConsola, Salud } from "../src/consola.ts";
import type { Resultado } from "../src/correcciones.ts";
import type { Repo } from "../src/repo.ts";

const ORG = "11111111-1111-4111-8111-111111111111";

/** Consola en memoria: registra las llamadas. */
class ConsolaFalsa implements Consola {
  llamadas: unknown[][] = [];
  suspendidas = new Set<string>();
  async suspendida(id: string) {
    return this.suspendidas.has(id);
  }
  async registrarCorrida(tarea: string, _inicio: Date, ok: boolean, detalle: unknown) {
    this.llamadas.push(["corrida", tarea, ok, detalle]);
  }
  async organizaciones(): Promise<OrganizacionConsola[]> {
    return [];
  }
  async crearOrganizacion(u: Usuario, d: { nombre: string; admin: string }): Promise<Resultado<{ id: string }>> {
    this.llamadas.push(["crear", u.email, d.nombre, d.admin]);
    return { ok: true, valor: { id: ORG } };
  }
  async cambiarTipo(_u: Usuario, id: string, tipo: string): Promise<Resultado<null>> {
    this.llamadas.push(["tipo", id, tipo]);
    return { ok: true, valor: null };
  }
  async suspender(_u: Usuario, id: string, s: boolean): Promise<Resultado<null>> {
    this.llamadas.push(["suspender", id, s]);
    if (s) this.suspendidas.add(id);
    else this.suspendidas.delete(id);
    return { ok: true, valor: null };
  }
  async uso() {
    return [];
  }
  async estadoDeCuentaCsv() {
    return "﻿Organización\r\n";
  }
  async salud(): Promise<Salud> {
    return { tareas: [], attestations: { pendientes: 0, conError: 0, masAntigua: null }, firma: { red: null, saldoEth: null }, fincasEnRojo: [] };
  }
  async solicitudes() {
    return [];
  }
  async equipo() {
    return [];
  }
  async invitar(_u: Usuario, id: string, email: string, rol: string): Promise<Resultado<null>> {
    this.llamadas.push(["invitar", id, email, rol]);
    return { ok: true, valor: null };
  }
  async cambiarRol(_u: Usuario, id: string, email: string, rol: string): Promise<Resultado<{ usuarioUid: string | null }>> {
    this.llamadas.push(["rol", id, email, rol]);
    return { ok: true, valor: { usuarioUid: "u-ana" } };
  }
  async cancelarInvitacion(_u: Usuario, id: string, email: string): Promise<Resultado<null>> {
    this.llamadas.push(["cancelar", id, email]);
    return { ok: true, valor: null };
  }
}

const usuarios: Record<string, Usuario> = {
  propietario: { uid: "u-go", email: "mauricio@goproduction.com", propietario: true },
  admin: { uid: "u-admin", email: "admin@coop.org", organizacionId: ORG, rol: "admin" },
};

function crearApp() {
  const consola = new ConsolaFalsa();
  const accesos: unknown[] = [];
  const repo = {
    organizacion: async () => ({ id: ORG, nombre: "Coop", tipo: "cooperativa", cultivos: ["cafe"], eliminacionProgramada: null }),
    actualizarCultivos: async () => [],
  } as unknown as Repo;
  const app = buildApp({
    repo,
    verificarToken: async (t) => usuarios[t] ?? null,
    identidad: { asignarAcceso: async (uid: string, a: unknown) => void accesos.push([uid, a]) } as never,
    almacen: {} as never,
    satelite: null,
    verificarTarea: async (t) => t === "oidc",
    consola,
  });
  const pedir = (method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE", url: string, token: string, payload?: object) =>
    app.inject({ method, url, headers: { authorization: `Bearer ${token}` }, payload });
  return { consola, accesos, pedir };
}

describe("consola del propietario", () => {
  it("es solo para el propietario", async () => {
    const { pedir } = crearApp();
    expect((await pedir("GET", "/v1/consola/organizaciones", "admin")).statusCode).toBe(403);
    expect((await pedir("GET", "/v1/consola/organizaciones", "propietario")).statusCode).toBe(200);
    expect((await pedir("GET", "/v1/consola/salud", "propietario")).json().attestations.pendientes).toBe(0);
  });

  it("crea una organización, cambia su tipo y maneja su equipo", async () => {
    const { consola, accesos, pedir } = crearApp();
    const creada = await pedir("POST", "/v1/consola/organizaciones", "propietario", {
      nombre: "Cooperativa Nueva", tipo: "cooperativa", cultivos: ["cafe"], admin: "Ana@Gmail.com",
    });
    expect(creada.statusCode).toBe(201);
    await pedir("PATCH", `/v1/consola/organizaciones/${ORG}`, "propietario", { tipo: "exportadora" });
    await pedir("POST", `/v1/consola/organizaciones/${ORG}/equipo`, "propietario", { email: "Beto@gmail.com", rol: "tecnico" });
    expect((await pedir("PUT", `/v1/consola/organizaciones/${ORG}/equipo/ana@gmail.com`, "propietario", { rol: "admin" })).statusCode).toBe(204);
    await pedir("DELETE", `/v1/consola/organizaciones/${ORG}/equipo/beto@gmail.com`, "propietario");
    expect(consola.llamadas).toEqual([
      ["crear", "mauricio@goproduction.com", "Cooperativa Nueva", "ana@gmail.com"],
      ["tipo", ORG, "exportadora"],
      ["invitar", ORG, "beto@gmail.com", "tecnico"],
      ["rol", ORG, "ana@gmail.com", "admin"],
      ["cancelar", ORG, "beto@gmail.com"],
    ]);
    expect(accesos).toEqual([["u-ana", { organizacionId: ORG, rol: "admin" }]]);
  });

  it("una organización suspendida ve lo suyo pero no carga datos nuevos", async () => {
    const { pedir } = crearApp();
    expect((await pedir("POST", `/v1/consola/organizaciones/${ORG}/suspender`, "propietario")).statusCode).toBe(204);
    expect((await pedir("GET", "/v1/organizacion", "admin")).statusCode).toBe(200);
    const escribir = await pedir("PUT", "/v1/organizacion/cultivos", "admin", { cultivos: ["cafe"] });
    expect(escribir.statusCode).toBe(403);
    expect(escribir.json().error).toBe("suspendida");
    await pedir("POST", `/v1/consola/organizaciones/${ORG}/reactivar`, "propietario");
    expect((await pedir("PUT", "/v1/organizacion/cultivos", "admin", { cultivos: ["cafe"] })).statusCode).toBe(200);
  });

  it("el uso pide el mes como AAAA-MM y el estado de cuenta sale en CSV", async () => {
    const { pedir } = crearApp();
    expect((await pedir("GET", "/v1/consola/uso?mes=2026-13", "propietario")).statusCode).toBe(422);
    expect((await pedir("GET", "/v1/consola/uso?mes=2026-11", "propietario")).statusCode).toBe(200);
    const csv = await pedir("GET", `/v1/consola/organizaciones/${ORG}/estado-de-cuenta?mes=2026-11`, "propietario");
    expect(csv.headers["content-type"]).toContain("text/csv");
  });

  it("cada corrida de una tarea programada queda registrada", async () => {
    const { consola } = crearApp();
    const app = buildApp({
      repo: {} as Repo,
      verificarToken: async () => null,
      identidad: {} as never,
      almacen: {} as never,
      satelite: null,
      verificarTarea: async (t) => t === "oidc",
      consola,
    });
    await app.inject({ method: "POST", url: "/v1/tareas/attestations", headers: { authorization: "Bearer oidc" } });
    await app.inject({ method: "POST", url: "/v1/tareas/attestations", headers: { authorization: "Bearer otro" } });
    expect(consola.llamadas.map((l) => [l[0], l[1], l[2]])).toEqual([["corrida", "attestations", false]]);
  });
});
