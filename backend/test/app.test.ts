import { geoHash, type Coordenada } from "@trazacafe/eudr-eas-schemas";
import { describe, expect, it } from "vitest";
import { rutaFoto, sha256Hex, type Almacen } from "../src/almacen.ts";
import { buildApp } from "../src/app.ts";
import type { Identidad, Rol, Usuario, UsuarioActivo } from "../src/auth.ts";
import { clasificar, type FuenteSatelital, type Hallazgos } from "../src/deforestacion.ts";
import {
  AccesoDenegado,
  aGeometria,
  desdeGeometria,
  VersionDesfasada,
  type Chequeo,
  type DatosOrganizacion,
  type FincaPorRevisar,
  type Invitacion,
  type Repo,
  type ResultadoEliminarFinca,
  type Temporada,
} from "../src/repo.ts";
import type { LoteSync, TemporadaNueva } from "../src/sync.ts";

const ORG = "11111111-1111-4111-8111-111111111111";
const OTRA_ORG = "22222222-2222-4222-8222-222222222222";

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

/** Repo en memoria con el mismo comportamiento que PgRepo. */
class RepoMemoria implements Repo {
  sync: { usuario: UsuarioActivo; datos: LoteSync }[] = [];
  invitaciones = new Map<string, Invitacion>();
  fallarSync?: Error;

  async guardarSync(usuario: UsuarioActivo, datos: LoteSync) {
    if (this.fallarSync) throw this.fallarSync;
    this.sync.push({ usuario, datos });
  }
  async buscarInvitacion(email: string) {
    return this.invitaciones.get(email.toLowerCase()) ?? null;
  }
  async aceptarInvitacion(email: string, uid: string) {
    const inv = this.invitaciones.get(email.toLowerCase());
    if (inv) Object.assign(inv, { usuarioUid: uid, aceptadaEn: inv.aceptadaEn ?? "ahora" });
  }
  async crearInvitacion(inv: Pick<Invitacion, "email" | "organizacionId" | "rol" | "invitadoPor">) {
    if (this.invitaciones.has(inv.email)) return false;
    this.invitaciones.set(inv.email, { ...inv, usuarioUid: null, creadoEn: "ahora", aceptadaEn: null });
    return true;
  }
  fincas = new Map<string, { organizacionId: string; atestada: boolean; archivos?: string[] }>();
  async eliminarFinca(organizacionId: string, fincaId: string): Promise<ResultadoEliminarFinca> {
    const f = this.fincas.get(fincaId);
    if (!f || f.organizacionId !== organizacionId) return { estado: "no_encontrada", archivos: [] };
    if (f.atestada) return { estado: "atestada", archivos: [] };
    this.fincas.delete(fincaId);
    return { estado: "eliminada", archivos: f.archivos ?? [] };
  }
  datos: DatosOrganizacion = { temporadas: [], productores: [], fincas: [], verificaciones: [], entregas: [] };
  async datosOrganizacion(organizacionId: string): Promise<DatosOrganizacion> {
    return organizacionId === ORG
      ? this.datos
      : { temporadas: [], productores: [], fincas: [], verificaciones: [], entregas: [] };
  }
  temporadas: (Temporada & { organizacionId: string })[] = [];
  async listarTemporadas(organizacionId: string) {
    return this.temporadas.filter((t) => t.organizacionId === organizacionId);
  }
  async crearTemporada(organizacionId: string, t: TemporadaNueva & { id: string }) {
    const traslapa = this.temporadas.some(
      (x) => x.organizacionId === organizacionId && x.inicio <= t.fin && t.inicio <= x.fin,
    );
    if (traslapa) return null;
    this.temporadas.push({ ...t, organizacionId });
    return { id: t.id, nombre: t.nombre, inicio: t.inicio, fin: t.fin };
  }
  porRevisar: FincaPorRevisar[] = [];
  chequeos: Chequeo[] = [];
  async fincasPorRevisar(limite: number) {
    return this.porRevisar.slice(0, limite);
  }
  async fincaParaRevisar(organizacionId: string, fincaId: string) {
    return organizacionId === ORG ? (this.porRevisar.find((f) => f.fincaId === fincaId) ?? null) : null;
  }
  async guardarChequeo(c: Chequeo) {
    this.chequeos.push(c);
  }
  fotos = new Map<string, { organizacionId: string; sha256: string; storagePath: string | null }>();
  async buscarFoto(organizacionId: string, fotoId: string) {
    const f = this.fotos.get(fotoId);
    return f && f.organizacionId === organizacionId ? f : null;
  }
  async marcarFotoSubida(fotoId: string, storagePath: string) {
    this.fotos.get(fotoId)!.storagePath = storagePath;
  }
  async listarInvitaciones(organizacionId: string) {
    return [...this.invitaciones.values()].filter((i) => i.organizacionId === organizacionId);
  }
  async eliminarInvitacion(organizacionId: string, email: string) {
    const inv = this.invitaciones.get(email);
    if (!inv || inv.organizacionId !== organizacionId) return null;
    this.invitaciones.delete(email);
    return inv;
  }
}

class IdentidadFalsa implements Identidad {
  claims = new Map<string, { organizacionId: string; rol: Rol }>();
  quitados: string[] = [];
  async asignarAcceso(uid: string, acceso: { organizacionId: string; rol: Rol }) {
    this.claims.set(uid, acceso);
  }
  async quitarAcceso(uid: string) {
    this.claims.delete(uid);
    this.quitados.push(uid);
  }
}

// Tokens de prueba: "token:<uid>:<email>" sin acceso, o con organización y rol.
const usuarios: Record<string, Usuario> = {
  tecnico: { uid: "u-tec", email: "tecnico@coop.org", organizacionId: ORG, rol: "tecnico" },
  admin: { uid: "u-admin", email: "admin@coop.org", organizacionId: ORG, rol: "admin" },
  nuevo: { uid: "u-nuevo", email: "Nuevo@Gmail.com" },
};

class AlmacenMemoria implements Almacen {
  archivos = new Map<string, Buffer>();
  borrados: string[] = [];
  async leer(ruta: string) {
    return this.archivos.get(ruta) ?? null;
  }
  async borrar(ruta: string) {
    this.archivos.delete(ruta);
    this.borrados.push(ruta);
  }
}

/** Satélite falso: devuelve los hallazgos indicados por id de finca. */
class SateliteFalso implements FuenteSatelital {
  nombre = "satelite falso";
  hallazgos: Hallazgos = { alertas: 0, haAlertas: 0, haPerdida: 0, detalle: {} };
  falla = false;
  async consultar() {
    if (this.falla) throw new Error("GFW caído");
    return this.hallazgos;
  }
}

function crearApp({ conSatelite = true } = {}) {
  const repo = new RepoMemoria();
  const identidad = new IdentidadFalsa();
  const almacen = new AlmacenMemoria();
  const satelite = new SateliteFalso();
  const app = buildApp({
    repo,
    identidad,
    almacen,
    satelite: conSatelite ? satelite : null,
    verificarToken: async (t) => usuarios[t] ?? null,
    verificarTarea: async (t) => t === "oidc-scheduler",
  });
  return { app, repo, identidad, almacen, satelite };
}

type App = ReturnType<typeof crearApp>["app"];

const pedir = (app: App, method: "GET" | "POST" | "DELETE", url: string, token: string, payload?: unknown) =>
  app.inject({ method, url, headers: { authorization: `Bearer ${token}` }, payload: payload as object });

describe("POST /v1/sync", () => {
  it("guarda productores y fincas para la organización y el usuario del token", async () => {
    const { app, repo } = crearApp();
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", { productores: [productor], fincas: [finca] });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      recibidos: { productores: 1, fincas: 1, versionesFinca: 0, verificaciones: 0, entregas: 0, fotos: 0 },
    });
    expect(repo.sync[0].usuario).toMatchObject({ uid: "u-tec", organizacionId: ORG });
  });

  it("rechaza sin token válido", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "POST", "/v1/sync", "otro", {})).statusCode).toBe(401);
  });

  it("rechaza a quien inició sesión pero no tiene acceso", async () => {
    const { app } = crearApp();
    const res = await pedir(app, "POST", "/v1/sync", "nuevo", { productores: [productor] });
    expect(res.statusCode).toBe(403);
    expect(res.json().error).toBe("sin_acceso");
  });

  it("rechaza un geoHash que no coincide con las coordenadas", async () => {
    const { app, repo } = crearApp();
    const alterada = { ...finca, coordenadas: [...coords.slice(0, 3), [-86.003, 13.093]] };
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { fincas: [alterada] })).statusCode).toBe(422);
    expect(repo.sync).toHaveLength(0);
  });

  it("rechaza un polígono cuyos linderos se cruzan", async () => {
    const { app, repo } = crearApp();
    const mono: Coordenada[] = [coords[0], coords[2], coords[1], coords[3]];
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", {
      fincas: [{ ...finca, coordenadas: mono, geoHash: geoHash(mono) }],
    });
    expect(res.statusCode).toBe(422);
    expect(JSON.stringify(res.json().detalles)).toContain("se cruzan");
    expect(repo.sync).toHaveLength(0);
  });

  it("rechaza un punto único para fincas de 4 ha o más", async () => {
    const { app } = crearApp();
    const punto: Coordenada[] = [[-86.235, 13.6305]];
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", {
      fincas: [{ ...finca, coordenadas: punto, geoHash: geoHash(punto), areaHa: 5 }],
    });
    expect(res.statusCode).toBe(422);
  });

  it("responde 403 si el productor es de otra organización", async () => {
    const { app, repo } = crearApp();
    repo.fallarSync = new AccesoDenegado("otra organización");
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { fincas: [finca] })).statusCode).toBe(403);
  });

  it("acepta fotos con hash válido y rechaza las mal formadas", async () => {
    const { app } = crearApp();
    const foto = {
      id: "9b2e1f4a-6c3d-4f8e-a1b2-3c4d5e6f7a8b",
      entidadTipo: "productor",
      entidadId: productor.id,
      tipo: "consentimiento",
      sha256: `0x${"cd".repeat(32)}`,
    };
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { fotos: [foto] })).statusCode).toBe(200);
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { fotos: [{ ...foto, sha256: "abc" }] })).statusCode).toBe(422);
  });

  it("rechaza productores sin consentimiento", async () => {
    const { app } = crearApp();
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", {
      productores: [{ ...productor, consentimientoFirmado: false }],
    });
    expect(res.statusCode).toBe(422);
  });
});

describe("POST /v1/activar", () => {
  it("asigna organización y rol si el correo tiene invitación (sin importar mayúsculas)", async () => {
    const { app, repo, identidad } = crearApp();
    await repo.crearInvitacion({ email: "nuevo@gmail.com", organizacionId: ORG, rol: "tecnico", invitadoPor: "u-admin" });

    const res = await pedir(app, "POST", "/v1/activar", "nuevo");
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ organizacionId: ORG, rol: "tecnico" });
    expect(identidad.claims.get("u-nuevo")).toEqual({ organizacionId: ORG, rol: "tecnico" });
    expect(repo.invitaciones.get("nuevo@gmail.com")?.usuarioUid).toBe("u-nuevo");
  });

  it("rechaza correos sin invitación", async () => {
    const { app, identidad } = crearApp();
    const res = await pedir(app, "POST", "/v1/activar", "nuevo");
    expect(res.statusCode).toBe(403);
    expect(res.json().error).toBe("sin_invitacion");
    expect(identidad.claims.size).toBe(0);
  });

  it("no deja que otra cuenta reutilice una invitación ya aceptada", async () => {
    const { app, repo } = crearApp();
    await repo.crearInvitacion({ email: "nuevo@gmail.com", organizacionId: ORG, rol: "tecnico", invitadoPor: "u-admin" });
    await repo.aceptarInvitacion("nuevo@gmail.com", "otra-cuenta");
    expect((await pedir(app, "POST", "/v1/activar", "nuevo")).statusCode).toBe(409);
  });

  it("si ya tiene acceso, solo lo devuelve", async () => {
    const { app } = crearApp();
    const res = await pedir(app, "POST", "/v1/activar", "admin");
    expect(res.json()).toEqual({ organizacionId: ORG, rol: "admin" });
  });
});

describe("/v1/invitaciones", () => {
  it("el administrador invita, lista y quita técnicos de su organización", async () => {
    const { app, repo, identidad } = crearApp();

    const creada = await pedir(app, "POST", "/v1/invitaciones", "admin", { email: "Juan@Gmail.com", rol: "tecnico" });
    expect(creada.statusCode).toBe(201);
    expect(repo.invitaciones.get("juan@gmail.com")).toMatchObject({ organizacionId: ORG, invitadoPor: "u-admin" });

    await repo.aceptarInvitacion("juan@gmail.com", "u-juan");
    const lista = await pedir(app, "GET", "/v1/invitaciones", "admin");
    expect(lista.json().invitaciones.map((i: Invitacion) => i.email)).toEqual(["juan@gmail.com"]);

    const borrada = await pedir(app, "DELETE", "/v1/invitaciones/juan@gmail.com", "admin");
    expect(borrada.statusCode).toBe(204);
    expect(identidad.quitados).toEqual(["u-juan"]);
  });

  it("no permite invitar un correo que ya está en otra organización", async () => {
    const { app, repo } = crearApp();
    await repo.crearInvitacion({ email: "juan@gmail.com", organizacionId: OTRA_ORG, rol: "tecnico", invitadoPor: "x" });
    expect((await pedir(app, "POST", "/v1/invitaciones", "admin", { email: "juan@gmail.com", rol: "tecnico" })).statusCode).toBe(409);
  });

  it("no permite borrar invitaciones de otra organización", async () => {
    const { app, repo } = crearApp();
    await repo.crearInvitacion({ email: "juan@gmail.com", organizacionId: OTRA_ORG, rol: "tecnico", invitadoPor: "x" });
    expect((await pedir(app, "DELETE", "/v1/invitaciones/juan@gmail.com", "admin")).statusCode).toBe(404);
    expect(repo.invitaciones.has("juan@gmail.com")).toBe(true);
  });

  it("el administrador no puede quitarse el acceso a sí mismo", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "DELETE", "/v1/invitaciones/ADMIN@coop.org", "admin")).statusCode).toBe(422);
  });

  it("los técnicos no pueden gestionar invitaciones", async () => {
    const { app } = crearApp();
    const res = await pedir(app, "POST", "/v1/invitaciones", "tecnico", { email: "x@gmail.com", rol: "admin" });
    expect(res.statusCode).toBe(403);
    expect(res.json().error).toBe("solo_admin");
    expect((await pedir(app, "GET", "/v1/invitaciones", "tecnico")).statusCode).toBe(403);
  });

  it("valida el correo y el rol", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "POST", "/v1/invitaciones", "admin", { email: "no-es-correo", rol: "tecnico" })).statusCode).toBe(422);
    expect((await pedir(app, "POST", "/v1/invitaciones", "admin", { email: "x@gmail.com", rol: "dueño" })).statusCode).toBe(422);
  });
});

describe("DELETE /v1/fincas/:id", () => {
  it("borra una finca de la organización que aún no se atestó", async () => {
    const { app, repo } = crearApp();
    repo.fincas.set(finca.id, { organizacionId: ORG, atestada: false });
    expect((await pedir(app, "DELETE", `/v1/fincas/${finca.id}`, "tecnico")).statusCode).toBe(204);
    expect(repo.fincas.has(finca.id)).toBe(false);
  });

  it("no borra fincas ya atestadas", async () => {
    const { app, repo } = crearApp();
    repo.fincas.set(finca.id, { organizacionId: ORG, atestada: true });
    const res = await pedir(app, "DELETE", `/v1/fincas/${finca.id}`, "tecnico");
    expect(res.statusCode).toBe(409);
    expect(res.json().error).toBe("atestada");
  });

  it("no borra fincas de otra organización", async () => {
    const { app, repo } = crearApp();
    repo.fincas.set(finca.id, { organizacionId: OTRA_ORG, atestada: false });
    expect((await pedir(app, "DELETE", `/v1/fincas/${finca.id}`, "tecnico")).statusCode).toBe(404);
    expect(repo.fincas.has(finca.id)).toBe(true);
  });

  it("exige acceso activo y un id válido", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "DELETE", `/v1/fincas/${finca.id}`, "nuevo")).statusCode).toBe(403);
    expect((await pedir(app, "DELETE", "/v1/fincas/no-es-uuid", "tecnico")).statusCode).toBe(404);
  });

  it("borra también las fotos de la finca en Storage", async () => {
    const { app, repo, almacen } = crearApp();
    const ruta = rutaFoto(ORG, "9b2e1f4a-6c3d-4f8e-a1b2-3c4d5e6f7a8b");
    repo.fincas.set(finca.id, { organizacionId: ORG, atestada: false, archivos: [ruta] });
    expect((await pedir(app, "DELETE", `/v1/fincas/${finca.id}`, "tecnico")).statusCode).toBe(204);
    expect(almacen.borrados).toEqual([ruta]);
  });
});

describe("entregas en /v1/sync", () => {
  const entrega = {
    id: "5d1c9e2a-7b3f-4a6d-9e8c-1f2a3b4c5d6e",
    fincaId: finca.id,
    kg: 345.5,
    estado: "uva",
    fecha: "2026-10-16T08:30:00.000-06:00",
  };

  it("acepta entregas válidas", async () => {
    const { app, repo } = crearApp();
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", { entregas: [entrega] });
    expect(res.statusCode).toBe(200);
    expect(repo.sync[0].datos.entregas[0]).toMatchObject({ kg: 345.5, estado: "uva" });
  });

  it.each([
    ["kg en cero", { kg: 0 }],
    ["más de 20 toneladas", { kg: 25_000 }],
    ["estado desconocido", { estado: "oro" }],
    ["fecha en el futuro", { fecha: new Date(Date.now() + 3 * 24 * 3600_000).toISOString() }],
    ["fecha sin zona horaria válida", { fecha: "16/10/2026" }],
  ])("rechaza %s", async (_, cambio) => {
    const { app, repo } = crearApp();
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { entregas: [{ ...entrega, ...cambio }] })).statusCode).toBe(422);
    expect(repo.sync).toHaveLength(0);
  });
});

describe("GET /v1/datos", () => {
  it("devuelve los datos de la organización del token", async () => {
    const { app, repo } = crearApp();
    repo.datos.productores.push({ ...productor, cedula: null, comunidad: null });
    const res = await pedir(app, "GET", "/v1/datos", "tecnico");
    expect(res.statusCode).toBe(200);
    expect(res.json().productores).toHaveLength(1);
  });

  it("exige acceso activo", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "GET", "/v1/datos", "nuevo")).statusCode).toBe(403);
  });
});

describe("POST /v1/fotos/:id/subida", () => {
  const fotoId = "9b2e1f4a-6c3d-4f8e-a1b2-3c4d5e6f7a8b";
  const contenido = Buffer.from("jpeg de prueba");

  function conFoto() {
    const ctx = crearApp();
    ctx.repo.fotos.set(fotoId, { organizacionId: ORG, sha256: sha256Hex(contenido), storagePath: null });
    return ctx;
  }

  it("acepta el archivo si su SHA-256 coincide y guarda la ruta", async () => {
    const { app, repo, almacen } = conFoto();
    almacen.archivos.set(rutaFoto(ORG, fotoId), contenido);
    const res = await pedir(app, "POST", `/v1/fotos/${fotoId}/subida`, "tecnico", {});
    expect(res.statusCode).toBe(200);
    expect(repo.fotos.get(fotoId)?.storagePath).toBe(rutaFoto(ORG, fotoId));
  });

  it("rechaza y borra un archivo distinto al registrado", async () => {
    const { app, repo, almacen } = conFoto();
    almacen.archivos.set(rutaFoto(ORG, fotoId), Buffer.from("otra foto"));
    const res = await pedir(app, "POST", `/v1/fotos/${fotoId}/subida`, "tecnico", {});
    expect(res.statusCode).toBe(422);
    expect(almacen.borrados).toEqual([rutaFoto(ORG, fotoId)]);
    expect(repo.fotos.get(fotoId)?.storagePath).toBeNull();
  });

  it("responde 409 si el archivo aún no está en Storage", async () => {
    const { app } = conFoto();
    expect((await pedir(app, "POST", `/v1/fotos/${fotoId}/subida`, "tecnico", {})).statusCode).toBe(409);
  });

  it("no deja confirmar fotos de otra organización", async () => {
    const { app, repo } = crearApp();
    repo.fotos.set(fotoId, { organizacionId: OTRA_ORG, sha256: sha256Hex(contenido), storagePath: null });
    expect((await pedir(app, "POST", `/v1/fotos/${fotoId}/subida`, "tecnico", {})).statusCode).toBe(404);
  });
});

describe("visitas y linderos nuevos en /v1/sync", () => {
  const otraForma: Coordenada[] = [
    [-86.0023, 13.091],
    [-86.0011, 13.091],
    [-86.0011, 13.0922],
    [-86.0023, 13.0922],
  ];
  const version = { fincaId: finca.id, version: 2, coordenadas: otraForma, areaHa: 1.4, geoHash: geoHash(otraForma) };
  const visita = {
    id: "8a7b6c5d-4e3f-4a1b-9c8d-7e6f5a4b3c2d",
    fincaId: finca.id,
    fecha: "2026-10-16T10:00:00.000-06:00",
    linderoCambio: true,
    versionFinca: 2,
    nota: "Amplió hacia el río",
  };

  it("acepta una visita con lindero nuevo", async () => {
    const { app, repo } = crearApp();
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", { versionesFinca: [version], verificaciones: [visita] });
    expect(res.statusCode).toBe(200);
    expect(repo.sync[0].datos.versionesFinca[0].version).toBe(2);
    expect(repo.sync[0].datos.verificaciones[0].linderoCambio).toBe(true);
  });

  it("aplica a la versión nueva las mismas reglas de geometría", async () => {
    const { app } = crearApp();
    const mono: Coordenada[] = [otraForma[0], otraForma[2], otraForma[1], otraForma[3]];
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", {
      versionesFinca: [{ ...version, coordenadas: mono, geoHash: geoHash(mono) }],
    });
    expect(res.statusCode).toBe(422);
  });

  it("no acepta versión 1 como lindero nuevo ni visitas en el futuro", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { versionesFinca: [{ ...version, version: 1 }] })).statusCode).toBe(422);
    const futuro = new Date(Date.now() + 5 * 24 * 3600_000).toISOString();
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { verificaciones: [{ ...visita, fecha: futuro }] })).statusCode).toBe(422);
  });

  it("responde 409 si otro técnico ya subió esa versión del lindero", async () => {
    const { app, repo } = crearApp();
    repo.fallarSync = new VersionDesfasada("La finca ya tiene una versión 2 distinta");
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", { versionesFinca: [version] });
    expect(res.statusCode).toBe(409);
    expect(res.json().error).toBe("version_desfasada");
  });

  it("acepta fotos de una visita", async () => {
    const { app } = crearApp();
    const foto = {
      id: "9b2e1f4a-6c3d-4f8e-a1b2-3c4d5e6f7a8b",
      entidadTipo: "verificacion",
      entidadId: visita.id,
      tipo: "verificacion",
      sha256: `0x${"ef".repeat(32)}`,
    };
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { verificaciones: [visita], fotos: [foto] })).statusCode).toBe(200);
  });
});

describe("/v1/temporadas", () => {
  const temporada = { nombre: "2026/27", inicio: "2026-10-01", fin: "2027-09-30" };

  it("el administrador crea una temporada y todos la ven", async () => {
    const { app } = crearApp();
    const res = await pedir(app, "POST", "/v1/temporadas", "admin", temporada);
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject(temporada);
    const lista = await pedir(app, "GET", "/v1/temporadas", "tecnico");
    expect(lista.json().temporadas).toHaveLength(1);
  });

  it("rechaza temporadas que se traslapan", async () => {
    const { app } = crearApp();
    await pedir(app, "POST", "/v1/temporadas", "admin", temporada);
    const res = await pedir(app, "POST", "/v1/temporadas", "admin", { nombre: "otra", inicio: "2027-09-01", fin: "2028-08-31" });
    expect(res.statusCode).toBe(409);
  });

  it("valida fechas y que solo el administrador cree temporadas", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "POST", "/v1/temporadas", "admin", { ...temporada, fin: "2026-09-01" })).statusCode).toBe(422);
    expect((await pedir(app, "POST", "/v1/temporadas", "admin", { ...temporada, inicio: "1/10/2026" })).statusCode).toBe(422);
    expect((await pedir(app, "POST", "/v1/temporadas", "tecnico", temporada)).statusCode).toBe(403);
  });
});

describe("chequeo satelital", () => {
  const porRevisar: FincaPorRevisar = {
    fincaId: finca.id,
    version: 1,
    temporadaId: "t1",
    geometria: aGeometria(coords) as FincaPorRevisar["geometria"],
  };

  it.each<[string, Partial<Hallazgos>, Chequeo["resultado"]]>([
    ["sin nada", {}, "verde"],
    ["una alerta sin área", { alertas: 1 }, "amarillo"],
    ["pérdida de 0.05 ha", { haPerdida: 0.05 }, "amarillo"],
    ["pérdida de 0.1 ha", { haPerdida: 0.1 }, "rojo"],
    ["alertas por 0.3 ha", { alertas: 4, haAlertas: 0.3 }, "rojo"],
  ])("clasifica %s como %s", (_, h, esperado) => {
    expect(clasificar({ alertas: 0, haAlertas: 0, haPerdida: 0, detalle: {}, ...h })).toBe(esperado);
  });

  it("la tarea programada exige el token de Cloud Scheduler", async () => {
    const { app } = crearApp();
    expect((await pedir(app, "POST", "/v1/tareas/chequeo-deforestacion", "admin", {})).statusCode).toBe(401);
  });

  it("la tarea revisa las fincas pendientes y guarda el resultado", async () => {
    const { app, repo, satelite } = crearApp();
    repo.porRevisar.push(porRevisar);
    satelite.hallazgos = { alertas: 2, haAlertas: 0.4, haPerdida: 0, detalle: {} };
    const res = await pedir(app, "POST", "/v1/tareas/chequeo-deforestacion", "oidc-scheduler", {});
    expect(res.json()).toMatchObject({ revisadas: 1, rojo: 1, errores: 0 });
    expect(repo.chequeos[0]).toMatchObject({ fincaId: finca.id, temporadaId: "t1", resultado: "rojo", areaAfectadaHa: 0.4 });
  });

  it("si el satélite falla en una finca, sigue con las demás", async () => {
    const { app, repo, satelite } = crearApp();
    repo.porRevisar.push(porRevisar);
    satelite.falla = true;
    const res = await pedir(app, "POST", "/v1/tareas/chequeo-deforestacion", "oidc-scheduler", {});
    expect(res.json()).toMatchObject({ revisadas: 0, errores: 1 });
    expect(repo.chequeos).toHaveLength(0);
  });

  it("sin API key de GFW responde 503 en vez de marcar fincas", async () => {
    const { app } = crearApp({ conSatelite: false });
    expect((await pedir(app, "POST", "/v1/tareas/chequeo-deforestacion", "oidc-scheduler", {})).statusCode).toBe(503);
  });

  it("el administrador puede revisar una finca en el momento", async () => {
    const { app, repo } = crearApp();
    repo.porRevisar.push(porRevisar);
    const res = await pedir(app, "POST", `/v1/fincas/${finca.id}/chequeo`, "admin", {});
    expect(res.json()).toMatchObject({ resultado: "verde" });
    expect((await pedir(app, "POST", `/v1/fincas/${finca.id}/chequeo`, "tecnico", {})).statusCode).toBe(403);
  });
});

describe("desdeGeometria", () => {
  it("es lo inverso de aGeometria", () => {
    expect(desdeGeometria(aGeometria(coords))).toEqual(coords);
    expect(desdeGeometria(aGeometria([[-86.235, 13.6305]]))).toEqual([[-86.235, 13.6305]]);
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
