import { geoHash, type Coordenada } from "@trazacafe/eudr-eas-schemas";
import { describe, expect, it } from "vitest";
import { rutaFoto, sha256Hex, type Almacen } from "../src/almacen.ts";
import { buildApp } from "../src/app.ts";
import type { ColaAttestations, RedEAS } from "../src/atestador.ts";
import type { Correcciones, Resultado } from "../src/correcciones.ts";
import type { Identidad, Rol, Usuario, UsuarioActivo } from "../src/auth.ts";
import { clasificar, type FuenteSatelital, type Hallazgos } from "../src/deforestacion.ts";
import type { CambiosExportacion, ExportacionNueva, LoteCandidato } from "../src/exportaciones.ts";
import type { EntregaCandidata } from "../src/lotes.ts";
import { fincaDePaquete, paqueteDePrueba } from "./datos-paquete.ts";
import {
  AccesoDenegado,
  aGeometria,
  DatosInvalidos,
  desdeGeometria,
  VersionDesfasada,
  type Chequeo,
  type DatosLote,
  type DatosOrganizacion,
  type Exportacion,
  type FincaPorRevisar,
  type Invitacion,
  type Lote,
  type Organizacion,
  type Paquete,
  type Repo,
  type ResultadoEliminarFinca,
  type Temporada,
} from "../src/repo.ts";
import type { LoteSync, TemporadaNueva } from "../src/sync.ts";
import type { CadenaPublica, Verificador } from "../src/verificador.ts";

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
  fincas = new Map<string, { organizacionId: string; atestada: boolean; enLote?: boolean; archivos?: string[] }>();
  async eliminarFinca(organizacionId: string, fincaId: string): Promise<ResultadoEliminarFinca> {
    const f = this.fincas.get(fincaId);
    if (!f || f.organizacionId !== organizacionId) return { estado: "no_encontrada", archivos: [] };
    if (f.atestada) return { estado: "atestada", archivos: [] };
    if (f.enLote) return { estado: "en_lote", archivos: [] };
    this.fincas.delete(fincaId);
    return { estado: "eliminada", archivos: f.archivos ?? [] };
  }
  /** Entregas de la organización ORG que la API puede poner en lotes. */
  candidatas: EntregaCandidata[] = [];
  lotes: (DatosLote & { organizacionId: string; atestado?: boolean })[] = [];
  async entregasCandidatas(organizacionId: string, filtro: { ids: string[] } | { cultivo: string; temporadaId: string }) {
    if (organizacionId !== ORG) return [];
    const enLote = (id: string) => this.lotes.find((l) => l.entregas.includes(id))?.codigo ?? null;
    return this.candidatas
      .filter((e) => ("ids" in filtro ? filtro.ids.includes(e.id) : e.cultivo === filtro.cultivo && e.temporadaId === filtro.temporadaId))
      .map((e) => ({ ...e, loteCodigo: e.loteCodigo ?? enLote(e.id) }));
  }
  async guardarLote(organizacionId: string, _uid: string, l: DatosLote) {
    if (this.lotes.some((x) => x.organizacionId === organizacionId && x.codigo === l.codigo)) return "codigo_repetido" as const;
    if (this.lotes.some((x) => x.entregas.some((e) => l.entregas.includes(e)))) return "entrega_ocupada" as const;
    this.lotes.push({ ...l, organizacionId });
    return "creado" as const;
  }
  async listarLotes(organizacionId: string): Promise<Lote[]> {
    return this.lotes
      .filter((l) => l.organizacionId === organizacionId)
      .map((l) => ({
        id: l.id,
        codigo: l.codigo,
        cultivo: l.cultivo,
        temporadaId: l.temporadaId,
        temporadaNombre: "2026/27",
        estado: l.estado,
        kg: l.kg,
        kgEsperados: l.kgEsperados,
        beneficio: l.beneficio,
        proceso: l.proceso ?? null,
        avisos: l.avisos,
        attestationUid: null,
        creadoEn: "2026-10-16T20:00:00.000Z",
        exportacionCodigo: null,
        entregas: [],
      }));
  }
  /** Lotes de ORG que pueden ir en contenedores. */
  lotesLibres: LoteCandidato[] = [];
  exportaciones: (ExportacionNueva & { id: string; cultivo: string; organizacionId: string; estado: "abierta" | "cerrada"; ddsRef?: string | null })[] = [];
  async lotesCandidatos(organizacionId: string, ids: string[]) {
    if (organizacionId !== ORG) return [];
    return this.lotesLibres
      .filter((l) => ids.includes(l.id))
      .map((l) => ({ ...l, exportacionCodigo: l.exportacionCodigo ?? this.exportaciones.find((x) => x.lotes.includes(l.id))?.codigo ?? null }));
  }
  async guardarExportacion(organizacionId: string, _uid: string, x: ExportacionNueva & { id: string; cultivo: string }) {
    if (this.exportaciones.some((e) => e.organizacionId === organizacionId && e.codigo === x.codigo)) return "codigo_repetido" as const;
    if (this.exportaciones.some((e) => e.lotes.some((l) => x.lotes.includes(l)))) return "lote_ocupado" as const;
    this.exportaciones.push({ ...x, organizacionId, estado: "abierta" });
    return "creada" as const;
  }
  async listarExportaciones(organizacionId: string): Promise<Exportacion[]> {
    return this.exportaciones
      .filter((x) => x.organizacionId === organizacionId)
      .map((x) => ({
        id: x.id,
        codigo: x.codigo,
        cultivo: x.cultivo,
        comprador: x.comprador,
        destino: x.destino,
        contenedor: x.contenedor ?? null,
        fechaEmbarque: x.fechaEmbarque ?? null,
        ddsRef: x.ddsRef ?? null,
        estado: x.estado,
        attestationUid: null,
        creadoEn: "2026-10-16T20:00:00.000Z",
        kg: 0,
        lotes: [],
        resumen: { entregas: 0, fincas: 0, areaOficialHa: 0, fincasSinVerde: 0 },
      }));
  }
  async actualizarExportacion(organizacionId: string, id: string, c: CambiosExportacion) {
    const x = this.exportaciones.find((e) => e.id === id && e.organizacionId === organizacionId);
    if (!x) return "no_encontrada" as const;
    const soloDds = Object.keys(c).every((k) => k === "ddsRef");
    if (x.estado === "cerrada" && !soloDds) return "cerrada" as const;
    Object.assign(x, c);
    return "cambiada" as const;
  }
  /** Fincas de origen que devuelve el paquete de cualquier contenedor de ORG. */
  fincasPaquete = paqueteDePrueba().fincas;
  async paqueteExportacion(organizacionId: string, id: string): Promise<Paquete | null> {
    const exportacion = (await this.listarExportaciones(organizacionId)).find((x) => x.id === id);
    return exportacion ? { organizacion: "Prueba", exportacion, fincas: this.fincasPaquete } : null;
  }
  colaAttestations: string[] = [];
  async cerrarExportacion(organizacionId: string, id: string) {
    const x = this.exportaciones.find((e) => e.id === id && e.organizacionId === organizacionId);
    if (!x) return "no_encontrada" as const;
    if (x.estado === "cerrada") return "cerrada" as const;
    x.estado = "cerrada";
    this.colaAttestations.push(`Exportacion:${id}`);
    return "cambiada" as const;
  }
  async eliminarExportacion(organizacionId: string, id: string) {
    const i = this.exportaciones.findIndex((e) => e.id === id && e.organizacionId === organizacionId);
    if (i < 0) return "no_encontrada" as const;
    if (this.exportaciones[i].estado === "cerrada") return "cerrada" as const;
    this.exportaciones.splice(i, 1);
    return "cambiada" as const;
  }
  async eliminarLote(organizacionId: string, loteId: string) {
    const i = this.lotes.findIndex((l) => l.id === loteId && l.organizacionId === organizacionId);
    if (i < 0) return "no_encontrado" as const;
    if (this.lotes[i].atestado) return "atestado" as const;
    this.lotes.splice(i, 1);
    return "eliminado" as const;
  }
  /** Fincas para cambiar de cultivo: cultivo actual y si tienen entregas. */
  cultivoFincas = new Map<string, { cultivo: string; conEntregas?: boolean; atestada?: boolean }>();
  async cambiarCultivoFinca(organizacionId: string, fincaId: string, cultivo: string) {
    const f = this.cultivoFincas.get(fincaId);
    if (!f || organizacionId !== ORG) return "no_encontrada" as const;
    if (f.conEntregas) return "con_entregas" as const;
    if (f.atestada) return "atestada" as const;
    f.cultivo = cultivo;
    return "cambiado" as const;
  }
  org: Organizacion = { id: ORG, nombre: "Prueba", tipo: "cooperativa", cultivos: ["cafe"], eliminacionProgramada: null };
  /** Cultivos que ya tienen fincas (no se pueden quitar). */
  cultivosConFincas: string[] = [];
  async organizacion(organizacionId: string) {
    return organizacionId === ORG ? this.org : null;
  }
  async actualizarCultivos(_: string, cultivos: string[]) {
    const bloqueados = this.cultivosConFincas.filter((c) => !cultivos.includes(c));
    if (bloqueados.length === 0) this.org = { ...this.org, cultivos };
    return bloqueados;
  }
  datos: DatosOrganizacion = {
    organizacion: this.org,
    temporadas: [],
    productores: [],
    fincas: [],
    verificaciones: [],
    entregas: [],
  };
  async datosOrganizacion(organizacionId: string): Promise<DatosOrganizacion> {
    return organizacionId === ORG
      ? this.datos
      : { organizacion: this.org, temporadas: [], productores: [], fincas: [], verificaciones: [], entregas: [] };
  }
  temporadas: (Temporada & { organizacionId: string })[] = [];
  async listarTemporadas(organizacionId: string) {
    return this.temporadas.filter((t) => t.organizacionId === organizacionId);
  }
  async crearTemporada(organizacionId: string, t: TemporadaNueva & { id: string }) {
    const traslapa = this.temporadas.some(
      (x) =>
        x.organizacionId === organizacionId &&
        (x.cultivo ?? null) === (t.cultivo ?? null) &&
        x.inicio <= t.fin &&
        t.inicio <= x.fin,
    );
    if (traslapa) return null;
    this.temporadas.push({ ...t, cultivo: t.cultivo ?? null, organizacionId });
    return { id: t.id, nombre: t.nombre, inicio: t.inicio, fin: t.fin, cultivo: t.cultivo ?? null };
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
  borrados: string[] = [];
  async eliminarUsuario(uid: string) {
    this.borrados.push(uid);
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

function crearApp({
  conSatelite = true,
  atestador = null,
  correcciones = null,
  verificador = null,
}: {
  conSatelite?: boolean;
  atestador?: { cola: ColaAttestations; red: RedEAS } | null;
  correcciones?: Correcciones | null;
  verificador?: Verificador | null;
} = {}) {
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
    atestador,
    correcciones,
    verificador,
  });
  return { app, repo, identidad, almacen, satelite };
}

type App = ReturnType<typeof crearApp>["app"];

const pedir = (app: App, method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE", url: string, token: string, payload?: unknown) =>
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
    ["estado desconocido", { estado: "tostado" }],
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

describe("cultivos", () => {
  it("una finca sin cultivo se toma como café (apps anteriores)", async () => {
    const { app, repo } = crearApp();
    await pedir(app, "POST", "/v1/sync", "tecnico", { fincas: [finca] });
    expect(repo.sync[0].datos.fincas[0].cultivo).toBe("cafe");
  });

  it("acepta una finca de cacao y rechaza un cultivo desconocido", async () => {
    const { app, repo } = crearApp();
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", { fincas: [{ ...finca, cultivo: "cacao" }] });
    expect(res.statusCode).toBe(200);
    expect(repo.sync[0].datos.fincas[0].cultivo).toBe("cacao");
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { fincas: [{ ...finca, cultivo: "soya" }] })).statusCode).toBe(422);
  });

  it("acepta estados de cacao en el formato y rechaza estados inexistentes", async () => {
    const { app } = crearApp();
    const entrega = { id: "5d1c9e2a-7b3f-4a6d-9e8c-1f2a3b4c5d6e", fincaId: finca.id, kg: 80, fecha: "2026-10-16T08:00:00Z" };
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { entregas: [{ ...entrega, estado: "fermentado" }] })).statusCode).toBe(200);
    expect((await pedir(app, "POST", "/v1/sync", "tecnico", { entregas: [{ ...entrega, estado: "tostado" }] })).statusCode).toBe(422);
  });

  it("un estado que no es del cultivo de la finca (cacao en uva) da 422 con el motivo", async () => {
    const { app, repo } = crearApp();
    repo.fallarSync = new DatosInvalidos('"uva" no es un estado de Cacao; use baba, fermentado, seco.');
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", {
      entregas: [{ id: "5d1c9e2a-7b3f-4a6d-9e8c-1f2a3b4c5d6e", fincaId: finca.id, kg: 80, estado: "uva", fecha: "2026-10-16T08:00:00Z" }],
    });
    expect(res.statusCode).toBe(422);
    expect(res.json().mensaje).toContain("Cacao");
  });

  it("el administrador cambia los cultivos de la organización", async () => {
    const { app, repo } = crearApp();
    const res = await pedir(app, "PUT", "/v1/organizacion/cultivos", "admin", { cultivos: ["cafe", "cacao"] });
    expect(res.statusCode).toBe(200);
    expect(repo.org.cultivos).toEqual(["cafe", "cacao"]);
    expect((await pedir(app, "GET", "/v1/organizacion", "tecnico")).json().cultivos).toEqual(["cafe", "cacao"]);
  });

  it("no deja quitar un cultivo que ya tiene fincas, ni dejar la lista vacía", async () => {
    const { app, repo } = crearApp();
    repo.cultivosConFincas = ["cafe"];
    const res = await pedir(app, "PUT", "/v1/organizacion/cultivos", "admin", { cultivos: ["cacao"] });
    expect(res.statusCode).toBe(409);
    expect(repo.org.cultivos).toEqual(["cafe"]);
    expect((await pedir(app, "PUT", "/v1/organizacion/cultivos", "admin", { cultivos: [] })).statusCode).toBe(422);
    expect((await pedir(app, "PUT", "/v1/organizacion/cultivos", "tecnico", { cultivos: ["cacao"] })).statusCode).toBe(403);
  });

  it("una temporada de cacao no choca con una general en las mismas fechas", async () => {
    const { app, repo } = crearApp();
    const t = { nombre: "2026/27", inicio: "2026-10-01", fin: "2027-09-30" };
    expect((await pedir(app, "POST", "/v1/temporadas", "admin", t)).statusCode).toBe(201);
    // Primero hay que activar el cacao en la organización.
    const sinCacao = await pedir(app, "POST", "/v1/temporadas", "admin", { ...t, nombre: "Cacao", cultivo: "cacao" });
    expect(sinCacao.statusCode).toBe(422);
    expect(sinCacao.json().mensaje).toContain("Cultivos");
    repo.org.cultivos = ["cafe", "cacao"];
    const cacao = await pedir(app, "POST", "/v1/temporadas", "admin", { ...t, nombre: "Cacao principal", cultivo: "cacao" });
    expect(cacao.statusCode).toBe(201);
    expect(cacao.json().cultivo).toBe("cacao");
    expect((await pedir(app, "POST", "/v1/temporadas", "admin", { ...t, nombre: "x", cultivo: "cacao" })).statusCode).toBe(409);
  });
});

describe("/v1/lotes", () => {
  const T = "33333333-3333-4333-8333-333333333333";
  let n = 0;
  const candidata = (p: Partial<EntregaCandidata> = {}): EntregaCandidata => ({
    id: `00000000-0000-4000-8000-${String(++n).padStart(12, "0")}`,
    fincaId: finca.id,
    fincaNombre: "La Esperanza",
    productorNombre: "Productora de prueba",
    cultivo: "cafe",
    temporadaId: T,
    kg: 500,
    estado: "uva",
    fecha: "2026-10-16T17:00:00.000Z",
    deforestacion: "verde",
    verificada: true,
    areaOficialHa: 4,
    kgExportablesFincaTemporada: 80,
    loteCodigo: null,
    ...p,
  });
  function preparar() {
    const c = crearApp();
    c.repo.temporadas.push({ id: T, nombre: "2026/27", inicio: "2026-10-01", fin: "2027-09-30", cultivo: null, organizacionId: ORG });
    return c;
  }
  const nuevo = (entregas: string[], p: object = {}) => ({
    codigo: "CAFE-001", cultivo: "cafe", temporadaId: T, estado: "pergamino", kg: 100, entregas, ...p,
  });

  it("el administrador arma un lote; se guarda con sus avisos y el beneficio por defecto", async () => {
    const { app, repo } = preparar();
    const e = candidata({ deforestacion: "pendiente" });
    repo.candidatas.push(e);
    const res = await pedir(app, "POST", "/v1/lotes", "admin", nuevo([e.id]));
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject({ codigo: "CAFE-001", kg: 100, beneficio: "Prueba" });
    expect(res.json().kgEsperados).toBeCloseTo(100);
    expect(res.json().avisos.map((a: { codigo: string }) => a.codigo)).toEqual(["satelite"]);
    expect((await pedir(app, "GET", "/v1/lotes", "admin")).json().lotes).toHaveLength(1);
  });

  it("rechaza el lote si una entrega es de una finca en rojo o sin visita, y dice cuál", async () => {
    const { app, repo } = preparar();
    const buena = candidata();
    const roja = candidata({ deforestacion: "rojo" });
    const sinVisita = candidata({ verificada: false });
    repo.candidatas.push(buena, roja, sinVisita);
    const res = await pedir(app, "POST", "/v1/lotes", "admin", nuevo([buena.id, roja.id, sinVisita.id]));
    expect(res.statusCode).toBe(422);
    expect(res.json().error).toBe("entregas_excluidas");
    expect(res.json().rechazos.map((r: { entregaId: string }) => r.entregaId)).toEqual([roja.id, sinVisita.id]);
    expect(repo.lotes).toHaveLength(0);
  });

  it("una entrega no va a dos lotes y el código no se repite", async () => {
    const { app, repo } = preparar();
    const a = candidata();
    const b = candidata();
    repo.candidatas.push(a, b);
    expect((await pedir(app, "POST", "/v1/lotes", "admin", nuevo([a.id]))).statusCode).toBe(201);
    const otraVez = await pedir(app, "POST", "/v1/lotes", "admin", nuevo([a.id], { codigo: "CAFE-002" }));
    expect(otraVez.statusCode).toBe(422);
    expect(otraVez.json().rechazos[0].motivo).toContain("CAFE-001");
    expect((await pedir(app, "POST", "/v1/lotes", "admin", nuevo([b.id]))).statusCode).toBe(409);
  });

  it("valida el estado del lote, el cultivo de la organización y la temporada", async () => {
    const { app, repo } = preparar();
    const e = candidata();
    repo.candidatas.push(e);
    expect((await pedir(app, "POST", "/v1/lotes", "admin", nuevo([e.id], { estado: "seco" }))).statusCode).toBe(422);
    expect((await pedir(app, "POST", "/v1/lotes", "admin", nuevo([e.id], { cultivo: "cacao", estado: "seco" }))).statusCode).toBe(422);
    const otraT = "44444444-4444-4444-8444-444444444444";
    expect((await pedir(app, "POST", "/v1/lotes", "admin", nuevo([e.id], { temporadaId: otraT }))).statusCode).toBe(422);
    expect((await pedir(app, "POST", "/v1/lotes", "admin", nuevo([]))).statusCode).toBe(422);
  });

  it("lista las entregas disponibles con el motivo de las que no pueden ir", async () => {
    const { app, repo } = preparar();
    const buena = candidata();
    const roja = candidata({ deforestacion: "rojo" });
    repo.candidatas.push(buena, roja, candidata({ cultivo: "cacao", estado: "seco" }));
    const res = await pedir(app, "GET", `/v1/lotes/disponibles?cultivo=cafe&temporadaId=${T}`, "admin");
    expect(res.statusCode).toBe(200);
    const entregas = res.json().entregas as { id: string; motivo: string | null }[];
    expect(entregas.map((e) => [e.id, e.motivo === null])).toEqual([[buena.id, true], [roja.id, false]]);
    expect((await pedir(app, "GET", "/v1/lotes/disponibles?cultivo=cafe", "admin")).statusCode).toBe(422);
  });

  it("solo los administradores ven y arman lotes", async () => {
    const { app } = preparar();
    expect((await pedir(app, "GET", "/v1/lotes", "tecnico")).statusCode).toBe(403);
    expect((await pedir(app, "POST", "/v1/lotes", "tecnico", nuevo([]))).statusCode).toBe(403);
  });

  it("deshace un lote que no está atestado; uno atestado no", async () => {
    const { app, repo } = preparar();
    const e = candidata();
    repo.candidatas.push(e);
    const id = (await pedir(app, "POST", "/v1/lotes", "admin", nuevo([e.id]))).json().id;
    repo.lotes[0].atestado = true;
    expect((await pedir(app, "DELETE", `/v1/lotes/${id}`, "admin")).statusCode).toBe(409);
    repo.lotes[0].atestado = false;
    expect((await pedir(app, "DELETE", `/v1/lotes/${id}`, "admin")).statusCode).toBe(204);
    expect(repo.lotes).toHaveLength(0);
    expect((await pedir(app, "DELETE", `/v1/lotes/${id}`, "admin")).statusCode).toBe(404);
  });

  it("no se borra una finca con entregas en un lote", async () => {
    const { app, repo } = preparar();
    repo.fincas.set(finca.id, { organizacionId: ORG, atestada: false, enLote: true });
    const res = await pedir(app, "DELETE", `/v1/fincas/${finca.id}`, "tecnico");
    expect(res.statusCode).toBe(409);
    expect(res.json().error).toBe("en_lote");
  });
});

describe("/v1/exportaciones", () => {
  const L1 = "55555555-5555-4555-8555-555555555551";
  const L2 = "55555555-5555-4555-8555-555555555552";
  const L3 = "55555555-5555-4555-8555-555555555553";
  function preparar() {
    const c = crearApp();
    c.repo.lotesLibres.push(
      { id: L1, codigo: "CAFE-001", cultivo: "cafe", exportacionCodigo: null },
      { id: L2, codigo: "CAFE-002", cultivo: "cafe", exportacionCodigo: null },
      { id: L3, codigo: "CACAO-001", cultivo: "cacao", exportacionCodigo: null },
    );
    return c;
  }
  const nueva = (lotes: string[], p: object = {}) => ({
    codigo: "EXP-2026-001", comprador: "Tostador GmbH", destino: "Hamburgo, Alemania", lotes, ...p,
  });

  it("el administrador arma un contenedor con lotes de café; el cultivo sale de los lotes", async () => {
    const { app, repo } = preparar();
    const res = await pedir(app, "POST", "/v1/exportaciones", "admin", nueva([L1, L2], { contenedor: "csqu3054383" }));
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject({ codigo: "EXP-2026-001", cultivo: "cafe", contenedor: "CSQU3054383", estado: "abierta" });
    expect(repo.exportaciones[0].lotes).toEqual([L1, L2]);
    expect((await pedir(app, "GET", "/v1/exportaciones", "admin")).json().exportaciones).toHaveLength(1);
  });

  it("rechaza mezclar cultivos, lotes ya embarcados y números de contenedor inválidos", async () => {
    const { app } = preparar();
    const mezcla = await pedir(app, "POST", "/v1/exportaciones", "admin", nueva([L1, L3]));
    expect(mezcla.statusCode).toBe(422);
    expect(mezcla.json().mensaje).toContain("un solo cultivo");
    expect((await pedir(app, "POST", "/v1/exportaciones", "admin", nueva([L1], { contenedor: "CSQU3054384" }))).statusCode).toBe(422);
    expect((await pedir(app, "POST", "/v1/exportaciones", "admin", nueva([L1]))).statusCode).toBe(201);
    const otraVez = await pedir(app, "POST", "/v1/exportaciones", "admin", nueva([L1], { codigo: "EXP-2026-002" }));
    expect(otraVez.statusCode).toBe(422);
    expect(otraVez.json().mensaje).toContain("EXP-2026-001");
    expect((await pedir(app, "POST", "/v1/exportaciones", "admin", nueva([L2]))).statusCode).toBe(409);
  });

  it("completa el número de contenedor y la DDS después; cerrado ya no cambia", async () => {
    const { app, repo } = preparar();
    const id = (await pedir(app, "POST", "/v1/exportaciones", "admin", nueva([L1]))).json().id;
    const res = await pedir(app, "PATCH", `/v1/exportaciones/${id}`, "admin", { contenedor: "CSQU3054383", ddsRef: "26NI000123" });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ contenedor: "CSQU3054383", ddsRef: "26NI000123" });
    expect((await pedir(app, "PATCH", `/v1/exportaciones/${id}`, "admin", {})).statusCode).toBe(422);
    repo.exportaciones[0].estado = "cerrada";
    expect((await pedir(app, "PATCH", `/v1/exportaciones/${id}`, "admin", { destino: "Amberes" })).statusCode).toBe(409);
    expect((await pedir(app, "DELETE", `/v1/exportaciones/${id}`, "admin")).statusCode).toBe(409);
  });

  it("deshace un contenedor abierto y solo los administradores lo usan", async () => {
    const { app, repo } = preparar();
    const id = (await pedir(app, "POST", "/v1/exportaciones", "admin", nueva([L1]))).json().id;
    expect((await pedir(app, "GET", "/v1/exportaciones", "tecnico")).statusCode).toBe(403);
    expect((await pedir(app, "DELETE", `/v1/exportaciones/${id}`, "tecnico")).statusCode).toBe(403);
    expect((await pedir(app, "DELETE", `/v1/exportaciones/${id}`, "admin")).statusCode).toBe(204);
    expect(repo.exportaciones).toHaveLength(0);
    expect((await pedir(app, "DELETE", `/v1/exportaciones/${id}`, "admin")).statusCode).toBe(404);
  });
});

describe("paquete EUDR del contenedor", () => {
  const L1 = "66666666-6666-4666-8666-666666666661";
  async function preparar(p: object = {}) {
    const c = crearApp();
    c.repo.lotesLibres.push({ id: L1, codigo: "CAFE-001", cultivo: "cafe", exportacionCodigo: null });
    const res = await pedir(c.app, "POST", "/v1/exportaciones", "admin", {
      codigo: "EXP 2026/001", comprador: "Tostador GmbH", destino: "Hamburgo", lotes: [L1], ...p,
    });
    return { ...c, id: res.json().id as string };
  }

  it("descarga el GeoJSON para TRACES, sin nombres de productores salvo que se pidan", async () => {
    const { app, id } = await preparar();
    const res = await pedir(app, "GET", `/v1/exportaciones/${id}/geojson`, "admin");
    expect(res.statusCode).toBe(200);
    expect(res.headers["content-type"]).toContain("application/geo+json");
    expect(res.headers["content-disposition"]).toContain('filename="EXP_2026_001.geojson"');
    const g = res.json();
    expect(g.features).toHaveLength(2);
    expect(g.features[0].properties.ProducerName).toBeUndefined();
    const con = await pedir(app, "GET", `/v1/exportaciones/${id}/geojson?productores=1`, "admin");
    expect(con.json().features[0].properties.ProducerName).toBe("Ana Pérez");
  });

  it("descarga el PDF para el comprador", async () => {
    const { app, id } = await preparar();
    const res = await pedir(app, "GET", `/v1/exportaciones/${id}/pdf`, "admin");
    expect(res.statusCode).toBe(200);
    expect(res.headers["content-type"]).toBe("application/pdf");
    expect(res.rawPayload.subarray(0, 5).toString()).toBe("%PDF-");
  });

  it("no cierra sin número de contenedor ni con fincas fuera de verde, y dice por qué", async () => {
    const { app, repo, id } = await preparar();
    repo.fincasPaquete = [fincaDePaquete({ nombre: "XXX", deforestacion: "pendiente" })];
    const res = await pedir(app, "POST", `/v1/exportaciones/${id}/cerrar`, "admin");
    expect(res.statusCode).toBe(409);
    expect(res.json().motivos).toEqual([
      "Falta el número de contenedor",
      "1 finca no tiene chequeo satelital verde: XXX (sin chequeo)",
    ]);
    expect(repo.exportaciones[0].estado).toBe("abierta");
  });

  it("cierra un paquete completo, encola su attestation y después solo acepta la DDS", async () => {
    const { app, repo, id } = await preparar({ contenedor: "CSQU3054383" });
    const res = await pedir(app, "POST", `/v1/exportaciones/${id}/cerrar`, "admin");
    expect(res.statusCode).toBe(200);
    expect(res.json().estado).toBe("cerrada");
    expect(repo.colaAttestations).toEqual([`Exportacion:${id}`]);
    expect((await pedir(app, "POST", `/v1/exportaciones/${id}/cerrar`, "admin")).statusCode).toBe(409);
    expect((await pedir(app, "PATCH", `/v1/exportaciones/${id}`, "admin", { ddsRef: "26NI000123" })).statusCode).toBe(200);
    expect((await pedir(app, "PATCH", `/v1/exportaciones/${id}`, "admin", { destino: "Amberes" })).statusCode).toBe(409);
  });

  it("solo administradores y solo contenedores de la organización", async () => {
    const { app, id } = await preparar();
    expect((await pedir(app, "GET", `/v1/exportaciones/${id}/pdf`, "tecnico")).statusCode).toBe(403);
    const otro = "77777777-7777-4777-8777-777777777777";
    expect((await pedir(app, "GET", `/v1/exportaciones/${otro}/geojson`, "admin")).statusCode).toBe(404);
    expect((await pedir(app, "POST", `/v1/exportaciones/${otro}/cerrar`, "admin")).statusCode).toBe(404);
  });
});

describe("correcciones", () => {
  const ID = "88888888-8888-4888-8888-888888888888";

  /** Servicio falso: registra las llamadas y responde lo que diga [respuesta]. */
  function falso(respuesta: Resultado<unknown> = { ok: true, valor: null }) {
    const llamadas: [string, string, string, unknown][] = [];
    const registrar =
      (nombre: string, valor: unknown = null) =>
      async (u: { uid: string }, id: string, datos?: unknown) => {
        llamadas.push([nombre, u.uid, id, datos]);
        return respuesta.ok ? { ok: true as const, valor } : respuesta;
      };
    const servicio = {
      corregirEntrega: registrar("corregirEntrega", { id: ID, kg: 500, estado: "uva", fecha: "2026-10-16T17:00:00.000Z", temporadaId: null }),
      anularEntrega: registrar("anularEntrega"),
      corregirLote: registrar("corregirLote"),
      corregirProductor: registrar("corregirProductor"),
      corregirFinca: registrar("corregirFinca"),
      eliminarFoto: registrar("eliminarFoto", { storagePath: "organizaciones/x/fotos/f.jpg" }),
      corregirVerificacion: registrar("corregirVerificacion"),
      anularVerificacion: registrar("anularVerificacion"),
      corregirTemporada: registrar("corregirTemporada"),
      eliminarTemporada: registrar("eliminarTemporada"),
    } as unknown as Correcciones;
    return { servicio, llamadas };
  }

  it("corrige una entrega con motivo y devuelve sus datos nuevos", async () => {
    const { servicio, llamadas } = falso();
    const { app } = crearApp({ correcciones: servicio });
    const res = await pedir(app, "PATCH", `/v1/entregas/${ID}`, "tecnico", { kg: 500, motivo: "un cero de más" });
    expect(res.statusCode).toBe(200);
    expect(res.json().kg).toBe(500);
    expect(llamadas).toEqual([["corregirEntrega", "u-tec", ID, { kg: 500, motivo: "un cero de más" }]]);
  });

  it("sin motivo al corregir kg responde 422 con el mensaje para la app", async () => {
    const { servicio, llamadas } = falso();
    const { app } = crearApp({ correcciones: servicio });
    const res = await pedir(app, "PATCH", `/v1/entregas/${ID}`, "tecnico", { kg: 500 });
    expect(res.statusCode).toBe(422);
    expect(res.json().mensaje).toBe("Escribe el motivo de la corrección");
    expect(llamadas).toHaveLength(0);
  });

  it("traduce los rechazos del servicio (en lote → 409, ajena → 403)", async () => {
    const enLote = falso({ ok: false, status: 409, mensaje: "La entrega está en el lote CAFE-001; para corregirla, primero deshaz el lote." });
    const r1 = await pedir(crearApp({ correcciones: enLote.servicio }).app, "POST", `/v1/entregas/${ID}/anular`, "tecnico", { motivo: "duplicada" });
    expect(r1.statusCode).toBe(409);
    expect(r1.json().mensaje).toContain("CAFE-001");
    const ajena = falso({ ok: false, status: 403, mensaje: "Solo quien lo registró o un administrador puede corregirlo." });
    expect((await pedir(crearApp({ correcciones: ajena.servicio }).app, "PATCH", `/v1/productores/${ID}`, "tecnico", { nombre: "Ana" })).statusCode).toBe(403);
  });

  it("anular responde 204; lotes y temporadas solo los corrige el administrador", async () => {
    const { servicio } = falso();
    const { app } = crearApp({ correcciones: servicio });
    expect((await pedir(app, "POST", `/v1/entregas/${ID}/anular`, "tecnico", { motivo: "duplicada" })).statusCode).toBe(204);
    expect((await pedir(app, "PATCH", `/v1/lotes/${ID}`, "tecnico", { codigo: "X" })).statusCode).toBe(403);
    expect((await pedir(app, "DELETE", `/v1/temporadas/${ID}`, "tecnico")).statusCode).toBe(403);
    expect((await pedir(app, "DELETE", `/v1/temporadas/${ID}`, "admin")).statusCode).toBe(204);
    expect((await pedir(app, "PATCH", `/v1/fincas/${ID}`, "tecnico", { nombre: "La Leonesa II" })).statusCode).toBe(204);
    expect((await pedir(app, "PATCH", `/v1/verificaciones/${ID}`, "tecnico", { nota: "sin cambios" })).statusCode).toBe(204);
  });

  it("quitar una foto también borra su archivo en Storage", async () => {
    const { servicio } = falso();
    const { app, almacen } = crearApp({ correcciones: servicio });
    expect((await pedir(app, "DELETE", `/v1/fotos/${ID}`, "tecnico")).statusCode).toBe(204);
    expect(almacen.borrados).toEqual(["organizaciones/x/fotos/f.jpg"]);
  });

  it("valida el id y que el servicio esté configurado", async () => {
    const { servicio } = falso();
    expect((await pedir(crearApp({ correcciones: servicio }).app, "PATCH", "/v1/entregas/no-es-uuid", "tecnico", { estado: "uva" })).statusCode).toBe(404);
    expect((await pedir(crearApp().app, "PATCH", `/v1/entregas/${ID}`, "tecnico", { estado: "uva" })).statusCode).toBe(503);
  });
});

describe("POST /v1/tareas/attestations", () => {
  const tarea = (app: App, token?: string) =>
    app.inject({ method: "POST", url: "/v1/tareas/attestations", headers: token ? { authorization: `Bearer ${token}` } : {} });

  it("solo la llama Cloud Scheduler con su token", async () => {
    const { app } = crearApp();
    expect((await tarea(app)).statusCode).toBe(401);
    expect((await tarea(app, "admin")).statusCode).toBe(401);
  });

  it("sin clave de firma responde 503", async () => {
    const { app } = crearApp();
    const res = await tarea(app, "oidc-scheduler");
    expect(res.statusCode).toBe(503);
    expect(res.json().error).toBe("sin_atestador");
  });

  it("firma la cola y devuelve el resumen", async () => {
    const cola: ColaAttestations = {
      listos: async (ola) =>
        ola === 1
          ? [{ esquema: "Finca", entidadId: "f1", version: 1, colaId: 1, solicitud: { esquema: "Finca", refUID: `0x${"0".repeat(64)}`, data: "0x01" } }]
          : [],
      guardar: async () => {},
      fallo: async () => {},
    };
    const red: RedEAS = { nombre: "optimism-sepolia", atestar: async () => ({ uids: [`0x${"a".repeat(64)}`], txHash: `0x${"b".repeat(64)}` }) };
    const { app } = crearApp({ atestador: { cola, red } });
    const res = await tarea(app, "oidc-scheduler");
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ firmadas: { Finca: 1 }, transacciones: [`0x${"b".repeat(64)}`], error: null });
  });
});

describe("PUT /v1/fincas/:id/cultivo", () => {
  const id = "3f2b8c1e-9a4d-4e7f-8b21-0c5d6e7f8a90";

  it("cambia el cultivo de una finca sin entregas", async () => {
    const { app, repo } = crearApp();
    repo.org.cultivos = ["cafe", "cacao"];
    repo.cultivoFincas.set(id, { cultivo: "cafe" });
    const res = await pedir(app, "PUT", `/v1/fincas/${id}/cultivo`, "tecnico", { cultivo: "cacao" });
    expect(res.statusCode).toBe(200);
    expect(repo.cultivoFincas.get(id)?.cultivo).toBe("cacao");
  });

  it("no lo cambia si la finca tiene entregas o ya está atestada", async () => {
    const { app, repo } = crearApp();
    repo.org.cultivos = ["cafe", "cacao"];
    repo.cultivoFincas.set(id, { cultivo: "cafe", conEntregas: true });
    const conEntregas = await pedir(app, "PUT", `/v1/fincas/${id}/cultivo`, "tecnico", { cultivo: "cacao" });
    expect(conEntregas.statusCode).toBe(409);
    expect(conEntregas.json().mensaje).toContain("entregas");
    repo.cultivoFincas.set(id, { cultivo: "cafe", atestada: true });
    expect((await pedir(app, "PUT", `/v1/fincas/${id}/cultivo`, "tecnico", { cultivo: "cacao" })).statusCode).toBe(409);
    expect(repo.cultivoFincas.get(id)?.cultivo).toBe("cafe");
  });

  it("rechaza un cultivo que la organización no tiene o que no existe, y fincas ajenas", async () => {
    const { app, repo } = crearApp();
    repo.cultivoFincas.set(id, { cultivo: "cafe" });
    const sinCacao = await pedir(app, "PUT", `/v1/fincas/${id}/cultivo`, "tecnico", { cultivo: "cacao" });
    expect(sinCacao.statusCode).toBe(422);
    expect(sinCacao.json().mensaje).toContain("Cultivos");
    expect((await pedir(app, "PUT", `/v1/fincas/${id}/cultivo`, "tecnico", { cultivo: "soya" })).statusCode).toBe(422);
    repo.org.cultivos = ["cafe", "cacao"];
    const otra = "11111111-2222-4333-8444-555555555555";
    expect((await pedir(app, "PUT", `/v1/fincas/${otra}/cultivo`, "tecnico", { cultivo: "cacao" })).statusCode).toBe(404);
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

describe("GET /v1/publico/:uid (verificador)", () => {
  const UID = `0x${"ab".repeat(32)}`;
  const cadena = { red: "optimism-sepolia", tipo: "Exportacion", uid: UID, fincas: [] } as unknown as CadenaPublica;
  const verificador: Verificador = { cadena: async (uid) => (uid === UID ? cadena : null) };

  it("responde sin sesión y desde cualquier página, con caché", async () => {
    const { app } = crearApp({ verificador });
    const res = await app.inject({ method: "GET", url: `/v1/publico/${UID}` });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual(cadena);
    expect(res.headers["access-control-allow-origin"]).toBe("*");
    expect(res.headers["cache-control"]).toBe("public, max-age=300");
  });

  it("un UID que no es de un contenedor o lote firmado da 404 con mensaje", async () => {
    const { app } = crearApp({ verificador });
    const res = await app.inject({ method: "GET", url: `/v1/publico/0x${"cd".repeat(32)}` });
    expect(res.statusCode).toBe(404);
    expect(res.json().mensaje).toContain("no corresponde");
    expect(res.headers["access-control-allow-origin"]).toBe("*");
  });

  it("un código mal formado da 400 sin consultar la base", async () => {
    let consultas = 0;
    const { app } = crearApp({ verificador: { cadena: async () => (consultas++, null) } });
    const res = await app.inject({ method: "GET", url: "/v1/publico/0x123" });
    expect(res.statusCode).toBe(400);
    expect(consultas).toBe(0);
  });
});
