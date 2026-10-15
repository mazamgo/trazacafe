import { geoHash, type Coordenada } from "@trazacafe/eudr-eas-schemas";
import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.ts";
import type { Identidad, Rol, Usuario, UsuarioActivo } from "../src/auth.ts";
import { AccesoDenegado, aGeometria, type Invitacion, type Repo } from "../src/repo.ts";
import type { LoteSync } from "../src/sync.ts";

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

function crearApp() {
  const repo = new RepoMemoria();
  const identidad = new IdentidadFalsa();
  const app = buildApp({ repo, identidad, verificarToken: async (t) => usuarios[t] ?? null });
  return { app, repo, identidad };
}

type App = ReturnType<typeof crearApp>["app"];

const pedir = (app: App, method: "GET" | "POST" | "DELETE", url: string, token: string, payload?: unknown) =>
  app.inject({ method, url, headers: { authorization: `Bearer ${token}` }, payload: payload as object });

describe("POST /v1/sync", () => {
  it("guarda productores y fincas para la organización y el usuario del token", async () => {
    const { app, repo } = crearApp();
    const res = await pedir(app, "POST", "/v1/sync", "tecnico", { productores: [productor], fincas: [finca] });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ recibidos: { productores: 1, fincas: 1, fotos: 0 } });
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
