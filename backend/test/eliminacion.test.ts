import { describe, expect, it } from "vitest";
import type { Almacen } from "../src/almacen.ts";
import { buildApp } from "../src/app.ts";
import type { Identidad, Usuario, UsuarioActivo } from "../src/auth.ts";
import type { Resultado } from "../src/correcciones.ts";
import {
  destinoFinca,
  solicitudProductorSchema,
  sumarAnios,
  type Eliminaciones,
  type ResultadoTarea,
  type ResumenEliminacion,
  type SolicitudEliminacion,
  type SolicitudProductor,
} from "../src/eliminacion.ts";
import type { Repo } from "../src/repo.ts";

const ORG = "11111111-1111-4111-8111-111111111111";
const PRODUCTOR = "7c9e6679-7425-40de-944b-e07fc1f90ae7";
const SOLICITUD = "5d1c9e2a-7b3f-4a6d-9e8c-1f2a3b4c5d6e";

describe("qué pasa con cada finca", () => {
  it("sin firmar ni en un lote se borra; exportada se guarda 5 años desde la exportación", () => {
    expect(destinoFinca({ sellada: false, ultimaExportacion: null }, "2026-10-21")).toEqual({ accion: "borrar" });
    expect(destinoFinca({ sellada: true, ultimaExportacion: "2026-03-15" }, "2026-10-21")).toEqual({
      accion: "anonimizar",
      conservarHasta: "2031-03-15",
    });
  });

  it("firmada o en un lote sin exportar se guarda 5 años desde hoy", () => {
    expect(destinoFinca({ sellada: true, ultimaExportacion: null }, "2026-10-21")).toEqual({
      accion: "anonimizar",
      conservarHasta: "2031-10-21",
    });
  });

  it("suma años sin inventar fechas (29 de febrero)", () => {
    expect(sumarAnios("2028-02-29", 5)).toBe("2033-02-28");
    expect(sumarAnios("2026-12-31", 5)).toBe("2031-12-31");
  });
});

describe("formulario público del productor", () => {
  const base = { organizacionId: ORG, nombre: "María López", contacto: "8888-0000" };

  it("pide nombre y un contacto; la cédula es opcional pero con formato", () => {
    expect(solicitudProductorSchema.safeParse(base).success).toBe(true);
    expect(solicitudProductorSchema.safeParse({ ...base, contacto: "" }).success).toBe(false);
    expect(solicitudProductorSchema.safeParse({ ...base, cedula: "001-010190-0001A" }).success).toBe(true);
    expect(solicitudProductorSchema.safeParse({ ...base, cedula: "12345" }).success).toBe(false);
  });

  it("acepta no saber la cooperativa", () => {
    expect(solicitudProductorSchema.safeParse({ ...base, organizacionId: null }).success).toBe(true);
  });
});

/** Eliminaciones en memoria: registra lo que la API le pide. */
class EliminacionesFalsa implements Eliminaciones {
  solicitudes: SolicitudProductor[] = [];
  pendientes: SolicitudEliminacion[] = [
    { id: SOLICITUD, nombre: "María López", cedula: null, comunidad: "El Tuma", contacto: "8888-0000", mensaje: null, creadaEn: "2026-10-20T15:00:00.000Z" },
  ];
  eliminados: string[] = [];
  rechazos: string[] = [];
  cuentas: string[] = [];
  unicoAdmin = false;
  programada: string | null = null;
  tarea: ResultadoTarea = { organizaciones: [], fincasPurgadas: 0, solicitudesSinRespuesta: 0 };
  archivos: string[] = [];
  borrados: string[] = [];
  fallidos: string[] = [];

  private resumen: ResumenEliminacion = { productor: "anonimizado", fincasBorradas: 1, fincasConservadas: 1, conservarHasta: "2031-03-15" };

  async organizacionesPublicas() {
    return [{ id: ORG, nombre: "Cooperativa Prueba" }];
  }
  async crearSolicitud(s: SolicitudProductor) {
    if (s.organizacionId && s.organizacionId !== ORG) return false;
    this.solicitudes.push(s);
    return true;
  }
  async solicitudesPendientes(org: string) {
    return org === ORG ? this.pendientes : [];
  }
  async contarPendientes(org: string) {
    return org === ORG ? this.pendientes.length : 0;
  }
  async aprobarSolicitud(_u: UsuarioActivo, id: string, productorId: string): Promise<Resultado<ResumenEliminacion>> {
    if (id !== SOLICITUD) return { ok: false, status: 404, mensaje: "No encontrada." };
    this.eliminados.push(productorId);
    this.pendientes = [];
    return { ok: true, valor: this.resumen };
  }
  async rechazarSolicitud(_u: UsuarioActivo, id: string, motivo: string): Promise<Resultado> {
    this.rechazos.push(`${id}:${motivo}`);
    return { ok: true, valor: null };
  }
  async eliminarProductor(_u: UsuarioActivo, productorId: string): Promise<Resultado<ResumenEliminacion>> {
    this.eliminados.push(productorId);
    return { ok: true, valor: this.resumen };
  }
  async eliminarCuenta(u: Usuario): Promise<Resultado> {
    if (this.unicoAdmin && u.rol === "admin") return { ok: false, status: 409, mensaje: "Eres el único administrador." };
    this.cuentas.push(u.uid);
    return { ok: true, valor: null };
  }
  async programarEliminacionOrganizacion(): Promise<Resultado<string>> {
    this.programada = "2026-11-20T15:00:00.000Z";
    return { ok: true, valor: this.programada };
  }
  async cancelarEliminacionOrganizacion(): Promise<Resultado> {
    if (!this.programada) return { ok: false, status: 409, mensaje: "No hay eliminación programada." };
    this.programada = null;
    return { ok: true, valor: null };
  }
  async tareaDiaria() {
    return this.tarea;
  }
  async archivosPorBorrar() {
    return this.archivos;
  }
  async archivosBorrados(borrados: string[], fallidos: string[]) {
    this.borrados.push(...borrados);
    this.fallidos.push(...fallidos);
  }
}

const usuarios: Record<string, Usuario> = {
  tecnico: { uid: "u-tec", email: "tecnico@coop.org", organizacionId: ORG, rol: "tecnico" },
  admin: { uid: "u-admin", email: "admin@coop.org", organizacionId: ORG, rol: "admin" },
  sinAcceso: { uid: "u-solo", email: "solo@gmail.com" },
};

function crearApp() {
  const eliminaciones = new EliminacionesFalsa();
  const identidad = { quitados: [] as string[], borrados: [] as string[] };
  const almacen: Almacen & { borrados: string[] } = {
    borrados: [],
    async leer() {
      return null;
    },
    async borrar(ruta) {
      if (ruta.includes("falla")) throw new Error("Storage caído");
      this.borrados.push(ruta);
    },
  };
  const ident: Identidad = {
    async asignarAcceso() {},
    async quitarAcceso(uid) {
      identidad.quitados.push(uid);
    },
    async eliminarUsuario(uid) {
      identidad.borrados.push(uid);
    },
  };
  const repo = {
    datosOrganizacion: async () => ({ organizacion: { id: ORG }, productores: [] }),
  } as unknown as Repo;
  const app = buildApp({
    repo,
    verificarToken: async (t) => usuarios[t] ?? null,
    identidad: ident,
    almacen,
    satelite: null,
    verificarTarea: async (t) => t === "oidc-scheduler",
    eliminaciones,
  });
  return { app, eliminaciones, identidad, almacen };
}

type App = ReturnType<typeof crearApp>["app"];
const pedir = (app: App, method: "GET" | "POST" | "DELETE" | "OPTIONS", url: string, token?: string, payload?: unknown) =>
  app.inject({
    method,
    url,
    headers: token ? { authorization: `Bearer ${token}` } : {},
    payload: payload as object,
  });

describe("página pública de eliminación", () => {
  const solicitud = { organizacionId: ORG, nombre: "María López", contacto: "8888-0000" };

  it("lista solo los nombres de las cooperativas, desde cualquier dominio", async () => {
    const { app } = crearApp();
    const res = await pedir(app, "GET", "/v1/publico/organizaciones");
    expect(res.json()).toEqual({ organizaciones: [{ id: ORG, nombre: "Cooperativa Prueba" }] });
    expect(res.headers["access-control-allow-origin"]).toBe("*");
    const previa = await pedir(app, "OPTIONS", "/v1/publico/solicitudes-eliminacion");
    expect(previa.statusCode).toBe(204);
    expect(previa.headers["access-control-allow-headers"]).toContain("authorization");
  });

  it("guarda la solicitud de un productor sin sesión", async () => {
    const { app, eliminaciones } = crearApp();
    const res = await pedir(app, "POST", "/v1/publico/solicitudes-eliminacion", undefined, solicitud);
    expect(res.statusCode).toBe(201);
    expect(eliminaciones.solicitudes).toHaveLength(1);
  });

  it("a un bot (campo trampa lleno) le responde igual pero no guarda nada", async () => {
    const { app, eliminaciones } = crearApp();
    const res = await pedir(app, "POST", "/v1/publico/solicitudes-eliminacion", undefined, { ...solicitud, sitio: "http://spam" });
    expect(res.statusCode).toBe(201);
    expect(eliminaciones.solicitudes).toHaveLength(0);
  });

  it("rechaza datos incompletos o una cooperativa que no existe", async () => {
    const { app } = crearApp();
    const sinContacto = await pedir(app, "POST", "/v1/publico/solicitudes-eliminacion", undefined, { ...solicitud, contacto: "" });
    expect(sinContacto.statusCode).toBe(422);
    expect(sinContacto.json().mensaje).toContain("teléfono o correo");
    const otra = await pedir(app, "POST", "/v1/publico/solicitudes-eliminacion", undefined, {
      ...solicitud,
      organizacionId: "99999999-9999-4999-8999-999999999999",
    });
    expect(otra.statusCode).toBe(422);
  });

  it("acepta pocas solicitudes por hora desde la misma IP", async () => {
    const { app } = crearApp();
    const codigos = [];
    for (let i = 0; i < 6; i++) {
      codigos.push((await pedir(app, "POST", "/v1/publico/solicitudes-eliminacion", undefined, solicitud)).statusCode);
    }
    expect(codigos).toEqual([201, 201, 201, 201, 201, 429]);
  });

  it("el límite no se salta falsificando X-Forwarded-For: cuenta la IP que agrega Cloud Run", async () => {
    const { app } = crearApp();
    const codigos = [];
    for (let i = 0; i < 6; i++) {
      // Lo de la izquierda lo escribe el cliente; Cloud Run agrega la IP real al final.
      const res = await app.inject({
        method: "POST",
        url: "/v1/publico/solicitudes-eliminacion",
        headers: { "x-forwarded-for": `10.0.0.${i}, 203.0.113.7` },
        payload: solicitud,
      });
      codigos.push(res.statusCode);
    }
    expect(codigos).toEqual([201, 201, 201, 201, 201, 429]);
  });
});

describe("solicitudes en la app del administrador", () => {
  it("el administrador las ve, las aprueba eligiendo al productor o las rechaza", async () => {
    const { app, eliminaciones } = crearApp();
    expect((await pedir(app, "GET", "/v1/solicitudes-eliminacion", "admin")).json().solicitudes).toHaveLength(1);
    const aprobada = await pedir(app, "POST", `/v1/solicitudes-eliminacion/${SOLICITUD}/aprobar`, "admin", { productorId: PRODUCTOR });
    expect(aprobada.statusCode).toBe(200);
    expect(aprobada.json()).toMatchObject({ productor: "anonimizado", conservarHasta: "2031-03-15" });
    expect(eliminaciones.eliminados).toEqual([PRODUCTOR]);

    const rechazada = await pedir(app, "POST", `/v1/solicitudes-eliminacion/${SOLICITUD}/rechazar`, "admin", { motivo: "no es productora nuestra" });
    expect(rechazada.statusCode).toBe(204);
    expect((await pedir(app, "POST", `/v1/solicitudes-eliminacion/${SOLICITUD}/rechazar`, "admin", {})).statusCode).toBe(422);
  });

  it("un técnico no puede verlas, aprobarlas ni eliminar productores", async () => {
    const { app, eliminaciones } = crearApp();
    expect((await pedir(app, "GET", "/v1/solicitudes-eliminacion", "tecnico")).statusCode).toBe(403);
    expect((await pedir(app, "POST", `/v1/solicitudes-eliminacion/${SOLICITUD}/aprobar`, "tecnico", { productorId: PRODUCTOR })).statusCode).toBe(403);
    expect((await pedir(app, "DELETE", `/v1/productores/${PRODUCTOR}`, "tecnico")).statusCode).toBe(403);
    expect(eliminaciones.eliminados).toEqual([]);
  });

  it("el administrador elimina directo a un productor que lo pidió en persona", async () => {
    const { app, eliminaciones } = crearApp();
    const res = await pedir(app, "DELETE", `/v1/productores/${PRODUCTOR}`, "admin", { motivo: "lo pidió en la oficina" });
    expect(res.statusCode).toBe(200);
    expect(eliminaciones.eliminados).toEqual([PRODUCTOR]);
  });

  it("los datos de la organización traen el conteo de solicitudes solo para el administrador", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "GET", "/v1/datos", "admin")).json().solicitudesPendientes).toBe(1);
    expect((await pedir(app, "GET", "/v1/datos", "tecnico")).json().solicitudesPendientes).toBe(0);
  });
});

describe("eliminar la propia cuenta", () => {
  it("quita el acceso y borra la cuenta de Firebase", async () => {
    const { app, eliminaciones, identidad } = crearApp();
    const res = await pedir(app, "DELETE", "/v1/cuenta", "tecnico");
    expect(res.statusCode).toBe(204);
    expect(res.headers["access-control-allow-origin"]).toBe("*");
    expect(eliminaciones.cuentas).toEqual(["u-tec"]);
    expect(identidad.quitados).toEqual(["u-tec"]);
    expect(identidad.borrados).toEqual(["u-tec"]);
  });

  it("también funciona sin organización (cuenta que nunca tuvo acceso)", async () => {
    const { app, identidad } = crearApp();
    expect((await pedir(app, "DELETE", "/v1/cuenta", "sinAcceso")).statusCode).toBe(204);
    expect(identidad.borrados).toEqual(["u-solo"]);
  });

  it("el único administrador no puede irse sin dejar a otro", async () => {
    const { app, eliminaciones, identidad } = crearApp();
    eliminaciones.unicoAdmin = true;
    const res = await pedir(app, "DELETE", "/v1/cuenta", "admin");
    expect(res.statusCode).toBe(409);
    expect(identidad.borrados).toEqual([]);
  });

  it("sin sesión responde 401", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "DELETE", "/v1/cuenta")).statusCode).toBe(401);
  });
});

describe("eliminar la organización", () => {
  it("el administrador la programa a 30 días y puede cancelarla", async () => {
    const { app, eliminaciones } = crearApp();
    const res = await pedir(app, "POST", "/v1/organizacion/eliminacion", "admin");
    expect(res.json()).toEqual({ eliminacionProgramada: "2026-11-20T15:00:00.000Z" });
    expect((await pedir(app, "DELETE", "/v1/organizacion/eliminacion", "admin")).statusCode).toBe(204);
    expect(eliminaciones.programada).toBeNull();
    expect((await pedir(app, "DELETE", "/v1/organizacion/eliminacion", "admin")).statusCode).toBe(409);
    expect((await pedir(app, "POST", "/v1/organizacion/eliminacion", "tecnico")).statusCode).toBe(403);
  });
});

describe("tarea diaria de eliminaciones", () => {
  it("borra las cuentas del equipo de las organizaciones vencidas y los archivos, con reintento", async () => {
    const { app, eliminaciones, identidad, almacen } = crearApp();
    eliminaciones.tarea = { organizaciones: [{ id: ORG, usuarios: ["u-admin", "u-tec"] }], fincasPurgadas: 2, solicitudesSinRespuesta: 1 };
    eliminaciones.archivos = ["organizaciones/o/fotos/a.jpg", "organizaciones/o/fotos/falla.jpg"];
    const res = await pedir(app, "POST", "/v1/tareas/eliminaciones", "oidc-scheduler");
    expect(res.json()).toEqual({ organizaciones: 1, cuentasBorradas: 2, fincasPurgadas: 2, archivosBorrados: 1, solicitudesSinRespuesta: 1 });
    expect(identidad.borrados).toEqual(["u-admin", "u-tec"]);
    expect(almacen.borrados).toEqual(["organizaciones/o/fotos/a.jpg"]);
    expect(eliminaciones.fallidos).toEqual(["organizaciones/o/fotos/falla.jpg"]);
  });

  it("solo la llama Cloud Scheduler", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "POST", "/v1/tareas/eliminaciones", "admin")).statusCode).toBe(401);
  });
});
