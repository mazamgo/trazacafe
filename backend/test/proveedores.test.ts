import { describe, expect, it } from "vitest";
import type { Almacen } from "../src/almacen.ts";
import { buildApp } from "../src/app.ts";
import type { Identidad, Usuario, UsuarioActivo } from "../src/auth.ts";
import type { Resultado } from "../src/correcciones.ts";
import { geojsonTraces, pdfPaquete } from "../src/paquete.ts";
import {
  avisoDiferencia,
  motivoNoVenta,
  observacionSchema,
  puedeTenerProveedores,
  recepcionSchema,
  ventaSchema,
  type AvisosRed,
  type LotePorRecibir,
  type Observacion,
  type ObservacionNueva,
  type Proveedores,
  type Recepcion,
  type Revision,
  type Venta,
  type Vinculo,
} from "../src/proveedores.ts";
import type { Lote, Repo } from "../src/repo.ts";
import { fincaDePaquete, paqueteDePrueba } from "./datos-paquete.ts";

const EXPORTADORA = "22222222-2222-4222-8222-222222222222";
const COOP = "11111111-1111-4111-8111-111111111111";
const VINCULO = "3f2a0000-0000-4000-8000-000000000001";
const LOTE = "4b1c0000-0000-4000-8000-000000000002";

describe("reglas de la venta", () => {
  const lote = { cultivo: "cafe", contenedor: null, vendidoA: null };
  const cliente = { estado: "activo", cliente: "Exportadora Norte", cultivos: ["cafe"] };

  it("un lote libre se vende a un cliente activo que trabaja su cultivo", () => {
    expect(motivoNoVenta(lote, cliente)).toBeNull();
  });

  it("no se vende si ya va en un contenedor, si ya se vendió o si el vínculo no está activo", () => {
    expect(motivoNoVenta({ ...lote, contenedor: "EXP-001" }, cliente)).toContain("contenedor EXP-001");
    expect(motivoNoVenta({ ...lote, vendidoA: "Otra" }, cliente)).toBe("El lote ya se vendió a Otra");
    expect(motivoNoVenta(lote, { ...cliente, estado: "pendiente" })).toBe("Esa organización no es un cliente activo");
    expect(motivoNoVenta(lote, null)).toBe("Esa organización no es un cliente activo");
  });

  it("no se vende cacao a quien solo trabaja café", () => {
    expect(motivoNoVenta({ ...lote, cultivo: "cacao" }, cliente)).toBe("Exportadora Norte no trabaja cacao");
  });

  it("solo exportadoras y beneficios tienen proveedores", () => {
    expect(puedeTenerProveedores("exportadora")).toBe(true);
    expect(puedeTenerProveedores("beneficio")).toBe(true);
    expect(puedeTenerProveedores("cooperativa")).toBe(false);
  });

  it("la fecha de envío o de recepción no puede estar en el futuro", () => {
    expect(ventaSchema.safeParse({ vinculoId: VINCULO, kg: 1000, fecha: "2026-10-01" }).success).toBe(true);
    const futura = ventaSchema.safeParse({ vinculoId: VINCULO, kg: 1000, fecha: "2099-01-01" });
    expect(futura.success).toBe(false);
    expect(futura.error?.issues[0].message).toBe("La fecha de envío no puede estar en el futuro");
    expect(recepcionSchema.safeParse({ kgRecibidos: 0, fecha: "2026-10-01" }).success).toBe(false);
  });

  it("una observación es sobre una finca o un lote, no sobre los dos", () => {
    expect(observacionSchema.safeParse({ fincaId: LOTE, texto: "Revisar el lindero" }).success).toBe(true);
    expect(observacionSchema.safeParse({ texto: "Revisar el lindero" }).success).toBe(false);
    expect(observacionSchema.safeParse({ fincaId: LOTE, loteId: LOTE, texto: "Revisar" }).success).toBe(false);
  });
});

describe("diferencia de kg al recibir", () => {
  it("sin diferencia no hay aviso", () => {
    expect(avisoDiferencia(1000, 1000)).toBeNull();
    expect(avisoDiferencia(1000, null)).toBeNull();
  });

  it("dice cuánto falta o sobra, en kg y en porcentaje", () => {
    expect(avisoDiferencia(1000, 980)).toEqual({
      codigo: "diferencia",
      mensaje: "Se recibieron 980 kg de 1,000 enviados (-20 kg, -2.0 %).",
    });
    expect(avisoDiferencia(1000, 1012.5)?.mensaje).toBe("Se recibieron 1,012.5 kg de 1,000 enviados (+12.5 kg, +1.3 %).");
  });
});

describe("paquete EUDR con fincas de proveedoras", () => {
  it("el GeoJSON no lleva el nombre del productor de una proveedora que no lo comparte", () => {
    const fincas = [fincaDePaquete(), fincaDePaquete({ id: "f2", nombre: "Finca 3F2A", productorNombre: null, proveedor: "Coop Sur" })];
    const g = geojsonTraces(fincas, { incluirProductor: true });
    expect(g.features[0].properties).toMatchObject({ ProducerName: "Ana Pérez" });
    expect(g.features[1].properties).not.toHaveProperty("ProducerName");
    expect(g.features[1].properties.ProductionPlace).toBe("Finca 3F2A, San Rafael del Norte");
  });

  it("el PDF se genera con proveedores y fincas de varias organizaciones", async () => {
    const p = paqueteDePrueba({
      proveedores: ["Coop Sur"],
      fincas: [fincaDePaquete(), fincaDePaquete({ id: "f2", nombre: "Finca 3F2A", productorNombre: null, proveedor: "Coop Sur" })],
    });
    const pdf = await pdfPaquete(p);
    expect(pdf.subarray(0, 5).toString()).toBe("%PDF-");
  });
});

const vinculo = (v: Partial<Vinculo> = {}): Vinculo => ({
  id: VINCULO,
  soy: "cliente",
  organizacion: { id: COOP, nombre: "Coop Sur" },
  estado: "activo",
  comparteNombres: false,
  invitadoEn: "2026-10-28T15:00:00.000Z",
  respondidoEn: "2026-10-28T16:00:00.000Z",
  terminadoEn: null,
  lotesEnviados: 1,
  lotesRecibidos: 0,
  ...v,
});

/** Red en memoria: registra lo que la API le pide y responde lo configurado. */
class ProveedoresFalsa implements Proveedores {
  llamadas: unknown[][] = [];
  lista: Vinculo[] = [vinculo(), vinculo({ id: "otro", soy: "proveedora", organizacion: { id: "x", nombre: "Exportadora Norte" } })];
  /** Resultado de las operaciones que cambian algo. */
  resultado: Resultado<unknown> = { ok: true, valor: null };

  private r<T>(nombre: string, valor: T, ...args: unknown[]): Promise<Resultado<T>> {
    this.llamadas.push([nombre, ...args]);
    return Promise.resolve(this.resultado.ok ? { ok: true, valor } : this.resultado);
  }
  async vinculos() {
    return this.lista;
  }
  invitar(u: UsuarioActivo, email: string) {
    return this.r("invitar", vinculo({ estado: "pendiente" }), u.organizacionId, email);
  }
  responder(u: UsuarioActivo, id: string, aceptar: boolean, comparteNombres: boolean) {
    return this.r("responder", vinculo({ soy: "proveedora" }), id, aceptar, comparteNombres);
  }
  cambiarNombres(u: UsuarioActivo, id: string, comparteNombres: boolean) {
    return this.r("cambiarNombres", vinculo({ soy: "proveedora", comparteNombres }), id, comparteNombres);
  }
  terminar(u: UsuarioActivo, id: string) {
    return this.r("terminar", null, id);
  }
  vender(u: UsuarioActivo, loteId: string, v: Venta) {
    return this.r("vender", null, loteId, v);
  }
  deshacerVenta(u: UsuarioActivo, loteId: string) {
    return this.r("deshacerVenta", null, loteId);
  }
  async porRecibir(): Promise<LotePorRecibir[]> {
    return [];
  }
  recibir(u: UsuarioActivo, loteId: string, r: Recepcion) {
    return this.r("recibir", { aviso: avisoDiferencia(1000, r.kgRecibidos) }, loteId, r);
  }
  revision(_org: string, id: string) {
    return this.r("revision", { vinculo: vinculo(), lotes: [], fincas: [], resumen: { fincas: 0, verdes: 0, conVisita: 0, areaOficialHa: 0 } } as Revision, id);
  }
  async observaciones(): Promise<Observacion[]> {
    return [];
  }
  observar(u: UsuarioActivo, o: ObservacionNueva) {
    return this.r("observar", { id: "o1", texto: o.texto } as Observacion, o);
  }
  responderObservacion(u: UsuarioActivo, id: string, texto: string) {
    return this.r("responderObservacion", null, id, texto);
  }
  async avisos(): Promise<AvisosRed> {
    return { invitaciones: [{ id: VINCULO, organizacion: "Exportadora Norte" }], lotesPorRecibir: 2, observacionesSinResponder: 1 };
  }
}

const usuarios: Record<string, Usuario> = {
  admin: { uid: "u-admin", email: "admin@exportadora.com", organizacionId: EXPORTADORA, rol: "admin" },
  tecnico: { uid: "u-tec", email: "tec@exportadora.com", organizacionId: EXPORTADORA, rol: "tecnico" },
};

function crearApp({ conRed = true } = {}) {
  const proveedores = new ProveedoresFalsa();
  const lote = { id: LOTE, codigo: "CAFE-001" } as Lote;
  const repo = { listarLotes: async () => [lote] } as unknown as Repo;
  const app = buildApp({
    repo,
    verificarToken: async (t) => usuarios[t] ?? null,
    identidad: {} as Identidad,
    almacen: {} as Almacen,
    satelite: null,
    verificarTarea: async () => false,
    proveedores: conRed ? proveedores : null,
  });
  return { app, proveedores };
}

type App = ReturnType<typeof crearApp>["app"];
const pedir = (app: App, method: "GET" | "POST" | "PATCH" | "DELETE", url: string, token = "admin", payload?: unknown) =>
  app.inject({ method, url, headers: { authorization: `Bearer ${token}` }, payload: payload as object });

describe("rutas de la red de proveedores", () => {
  it("son solo de administradores", async () => {
    const { app } = crearApp();
    for (const [m, url] of [
      ["GET", "/v1/proveedores"],
      ["GET", "/v1/clientes"],
      ["GET", "/v1/red/avisos"],
      ["POST", `/v1/lotes/${LOTE}/venta`],
    ] as const) {
      expect((await pedir(app, m, url, "tecnico")).statusCode).toBe(403);
    }
  });

  it("responden 503 si la red no está disponible", async () => {
    const { app } = crearApp({ conRed: false });
    expect((await pedir(app, "GET", "/v1/proveedores")).statusCode).toBe(503);
  });

  it("la exportadora ve sus proveedoras y la cooperativa sus clientes", async () => {
    const { app } = crearApp();
    const prov = (await pedir(app, "GET", "/v1/proveedores")).json();
    expect(prov.proveedores.map((v: Vinculo) => v.organizacion.nombre)).toEqual(["Coop Sur"]);
    expect(prov.porRecibir).toEqual([]);
    const cli = (await pedir(app, "GET", "/v1/clientes")).json();
    expect(cli.clientes.map((v: Vinculo) => v.organizacion.nombre)).toEqual(["Exportadora Norte"]);
  });

  it("invita por correo, en minúsculas, y traduce los rechazos", async () => {
    const { app, proveedores } = crearApp();
    const res = await pedir(app, "POST", "/v1/proveedores", "admin", { email: "Admin@CoopSur.org" });
    expect(res.statusCode).toBe(201);
    expect(proveedores.llamadas[0]).toEqual(["invitar", EXPORTADORA, "admin@coopsur.org"]);

    proveedores.resultado = { ok: false, status: 404, mensaje: "Ese correo no es de un administrador activo en TrazaCafé." };
    const no = await pedir(app, "POST", "/v1/proveedores", "admin", { email: "nadie@gmail.com" });
    expect(no.statusCode).toBe(404);
    expect(no.json().mensaje).toContain("administrador activo");

    expect((await pedir(app, "POST", "/v1/proveedores", "admin", { email: "no-es-correo" })).statusCode).toBe(422);
  });

  it("la cooperativa acepta eligiendo si comparte nombres; rechazar no los comparte", async () => {
    const { app, proveedores } = crearApp();
    expect((await pedir(app, "POST", `/v1/clientes/${VINCULO}/aceptar`, "admin", { comparteNombres: true })).statusCode).toBe(200);
    expect((await pedir(app, "POST", `/v1/clientes/${VINCULO}/aceptar`, "admin", {})).statusCode).toBe(422);
    expect((await pedir(app, "POST", `/v1/clientes/${VINCULO}/rechazar`)).statusCode).toBe(200);
    expect(proveedores.llamadas).toEqual([
      ["responder", VINCULO, true, true],
      ["responder", VINCULO, false, false],
    ]);
  });

  it("vende un lote y devuelve el lote actualizado; deshacer responde 204", async () => {
    const { app, proveedores } = crearApp();
    const venta = { vinculoId: VINCULO, kg: 1000, fecha: "2026-10-27" };
    const res = await pedir(app, "POST", `/v1/lotes/${LOTE}/venta`, "admin", venta);
    expect(res.statusCode).toBe(200);
    expect(res.json().codigo).toBe("CAFE-001");
    expect(proveedores.llamadas[0]).toEqual(["vender", LOTE, venta]);
    expect((await pedir(app, "DELETE", `/v1/lotes/${LOTE}/venta`)).statusCode).toBe(204);

    proveedores.resultado = { ok: false, status: 409, mensaje: "La exportadora ya puso el lote en un contenedor." };
    expect((await pedir(app, "DELETE", `/v1/lotes/${LOTE}/venta`)).statusCode).toBe(409);
  });

  it("recibe un lote con su aviso de diferencia", async () => {
    const { app } = crearApp();
    const res = await pedir(app, "POST", `/v1/proveedores/lotes/${LOTE}/recibir`, "admin", { kgRecibidos: 980, fecha: "2026-10-28" });
    expect(res.statusCode).toBe(200);
    expect(res.json().aviso.codigo).toBe("diferencia");
  });

  it("un id que no es uuid responde 404 sin llegar a la base", async () => {
    const { app, proveedores } = crearApp();
    expect((await pedir(app, "GET", "/v1/proveedores/abc/revision")).statusCode).toBe(404);
    expect((await pedir(app, "DELETE", "/v1/clientes/abc")).statusCode).toBe(404);
    expect(proveedores.llamadas).toEqual([]);
  });

  it("revisión, observaciones y avisos", async () => {
    const { app, proveedores } = crearApp();
    expect((await pedir(app, "GET", `/v1/proveedores/${VINCULO}/revision`)).json().vinculo.id).toBe(VINCULO);
    const obs = await pedir(app, "POST", "/v1/observaciones", "admin", { fincaId: LOTE, texto: "Revisar el lindero norte" });
    expect(obs.statusCode).toBe(201);
    expect((await pedir(app, "POST", "/v1/observaciones/abc/respuesta", "admin", { texto: "Listo" })).statusCode).toBe(404);
    const resp = await pedir(app, "POST", `/v1/observaciones/${VINCULO}/respuesta`, "admin", { texto: "Ya se corrigió" });
    expect(resp.statusCode).toBe(204);
    expect(proveedores.llamadas.at(-1)).toEqual(["responderObservacion", VINCULO, "Ya se corrigió"]);
    expect((await pedir(app, "GET", "/v1/red/avisos")).json()).toMatchObject({ lotesPorRecibir: 2, observacionesSinResponder: 1 });
  });
});
