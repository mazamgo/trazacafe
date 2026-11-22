import { ID_CULTIVOS } from "@trazacafe/eudr-eas-schemas";
import type pg from "pg";
import { z } from "zod";
import type { Usuario } from "./auth.ts";
import { CobrosPg, type EstadoDeCuenta } from "./cobros.ts";
import type { Resultado } from "./correcciones.ts";
import { csv } from "./csv.ts";
import { AREA_OFICIAL } from "./repo.ts";

/**
 * Consola del propietario (GoProduction): organizaciones, uso y facturación,
 * salud del sistema, solicitudes y soporte. Solo para cuentas con el claim
 * `propietario` (se asigna con `npm run propietario`). Muestra números por
 * organización, nunca nombres ni cédulas de productores (Ley 787), y cada
 * acción queda en `historial_consola`.
 */

export const TIPOS_ORGANIZACION = ["cooperativa", "exportadora", "beneficio", "otra", "importador"] as const;
const rol = z.enum(["admin", "tecnico"]);
const correo = z.email().transform((e) => e.toLowerCase());

export const organizacionNuevaSchema = z.object({
  nombre: z.string().trim().min(2).max(120),
  tipo: z.enum(TIPOS_ORGANIZACION),
  cultivos: z.array(z.enum(ID_CULTIVOS)).min(1).default(["cafe"]),
  admin: correo,
});
export const cambioOrganizacionSchema = z.object({ tipo: z.enum(TIPOS_ORGANIZACION) });
export const invitacionConsolaSchema = z.object({ email: correo, rol });
export const rolSchema = z.object({ rol });
export const mesSchema = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/);

export interface OrganizacionConsola {
  id: string;
  nombre: string;
  tipo: string;
  cultivos: string[];
  suspendida: boolean;
  eliminacionProgramada: string | null;
  administradores: number;
  usuarios: number;
  productores: number;
  fincas: number;
  hectareas: number;
  contenedoresCerrados: number;
  plan: string | null;
  estadoContrato: string | null;
}

export interface UsoMes {
  organizacionId: string;
  nombre: string;
  productoresActivos: number;
  fincas: number;
  hectareas: number;
  contenedoresMes: number;
  totalUsd: number;
  sinContrato: number;
  quedanBolsa: number | null;
}

export interface Salud {
  tareas: { tarea: string; ultima: string | null; ok: boolean | null; detalle: unknown }[];
  attestations: { pendientes: number; conError: number; masAntigua: string | null };
  firma: { red: string | null; saldoEth: string | null };
  fincasEnRojo: { organizacion: string; fincas: number }[];
}

export interface SolicitudConsola {
  id: string;
  organizacion: string | null;
  creadaEn: string;
  dias: number;
}

export interface MiembroEquipo {
  email: string;
  rol: string;
  activo: boolean;
}

export interface Consola {
  suspendida(organizacionId: string): Promise<boolean>;
  registrarCorrida(tarea: string, inicio: Date, ok: boolean, detalle: unknown): Promise<void>;
  organizaciones(): Promise<OrganizacionConsola[]>;
  crearOrganizacion(u: Usuario, d: z.infer<typeof organizacionNuevaSchema>): Promise<Resultado<{ id: string }>>;
  cambiarTipo(u: Usuario, id: string, tipo: string): Promise<Resultado<null>>;
  suspender(u: Usuario, id: string, suspender: boolean): Promise<Resultado<null>>;
  uso(mes: string): Promise<UsoMes[]>;
  estadoDeCuentaCsv(id: string, mes: string): Promise<string | null>;
  salud(): Promise<Salud>;
  solicitudes(): Promise<SolicitudConsola[]>;
  equipo(id: string): Promise<MiembroEquipo[]>;
  invitar(u: Usuario, id: string, email: string, rol: string): Promise<Resultado<null>>;
  /** Devuelve el uid de la persona si ya entró (para actualizar su acceso). */
  cambiarRol(u: Usuario, id: string, email: string, rol: string): Promise<Resultado<{ usuarioUid: string | null }>>;
  cancelarInvitacion(u: Usuario, id: string, email: string): Promise<Resultado<null>>;
}

const ok = <T>(valor: T): Resultado<T> => ({ ok: true, valor });
const no = (status: 403 | 404 | 409 | 422, mensaje: string): Resultado<never> => ({ ok: false, status, mensaje });
const TAREAS = ["chequeo-deforestacion", "attestations", "eliminaciones"];

export class ConsolaPg implements Consola {
  constructor(
    private readonly pool: pg.Pool,
    /** Saldo de ETH de la dirección que firma, y su red; `null` sin clave de firma. */
    private readonly firma: { red: string; saldo: () => Promise<string> } | null = null,
  ) {}

  private historial(u: Usuario, accion: string, organizacionId: string | null, detalle: unknown) {
    return this.pool.query(
      "INSERT INTO historial_consola (usuario_uid, email, accion, organizacion_id, detalle) VALUES ($1, $2, $3, $4, $5)",
      [u.uid, u.email, accion, organizacionId, JSON.stringify(detalle)],
    );
  }

  async suspendida(organizacionId: string) {
    const { rows: [o] } = await this.pool.query<{ s: boolean }>(
      "SELECT suspendida_en IS NOT NULL AS s FROM organizaciones WHERE id = $1",
      [organizacionId],
    );
    return o?.s ?? false;
  }

  async registrarCorrida(tarea: string, inicio: Date, okTarea: boolean, detalle: unknown) {
    await this.pool.query("INSERT INTO corridas_tareas (tarea, inicio, ok, detalle) VALUES ($1, $2, $3, $4)", [
      tarea,
      inicio,
      okTarea,
      JSON.stringify(detalle ?? {}),
    ]);
  }

  async organizaciones(): Promise<OrganizacionConsola[]> {
    const { rows } = await this.pool.query(
      `SELECT o.id, o.nombre, o.tipo, o.cultivos, o.suspendida_en IS NOT NULL AS suspendida,
              o.eliminacion_programada AS "eliminacionProgramada",
              (SELECT count(*)::int FROM invitaciones i WHERE i.organizacion_id = o.id AND i.rol = 'admin') AS administradores,
              (SELECT count(*)::int FROM invitaciones i WHERE i.organizacion_id = o.id) AS usuarios,
              (SELECT count(*)::int FROM productores p WHERE p.organizacion_id = o.id AND p.anonimizado_en IS NULL) AS productores,
              (SELECT count(*)::int FROM fincas f JOIN productores p ON p.id = f.productor_id
               WHERE p.organizacion_id = o.id AND f.anonimizada_en IS NULL) AS fincas,
              coalesce((SELECT sum(${AREA_OFICIAL("f")}) FROM fincas f JOIN productores p ON p.id = f.productor_id
               WHERE p.organizacion_id = o.id AND f.anonimizada_en IS NULL), 0)::float8 AS hectareas,
              (SELECT count(*)::int FROM consumos c WHERE c.organizacion_id = o.id AND c.tipo = 'contenedor') AS "contenedoresCerrados",
              ct.plan, ct.estado AS "estadoContrato"
       FROM organizaciones o
       LEFT JOIN LATERAL (SELECT plan, estado FROM contratos c WHERE c.organizacion_id = o.id ORDER BY c.inicio DESC LIMIT 1) ct ON true
       WHERE o.eliminada_en IS NULL
       ORDER BY o.nombre`,
    );
    return rows.map((r) => ({
      ...r,
      hectareas: Math.round(r.hectareas * 100) / 100,
      eliminacionProgramada: r.eliminacionProgramada ? new Date(r.eliminacionProgramada).toISOString() : null,
    }));
  }

  async crearOrganizacion(u: Usuario, d: z.infer<typeof organizacionNuevaSchema>) {
    const id = crypto.randomUUID();
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("INSERT INTO organizaciones (id, nombre, tipo, cultivos) VALUES ($1, $2, $3, $4)", [
        id,
        d.nombre,
        d.tipo,
        [...new Set(d.cultivos)],
      ]);
      await client.query("INSERT INTO invitaciones (email, organizacion_id, rol, invitado_por) VALUES ($1, $2, 'admin', $3)", [
        d.admin,
        id,
        u.uid,
      ]);
      await client.query(
        "INSERT INTO historial_consola (usuario_uid, email, accion, organizacion_id, detalle) VALUES ($1, $2, 'crear_organizacion', $3, $4)",
        [u.uid, u.email, id, JSON.stringify({ nombre: d.nombre, tipo: d.tipo, admin: d.admin })],
      );
      await client.query("COMMIT");
      return ok({ id });
    } catch (e) {
      await client.query("ROLLBACK");
      if ((e as { code?: string }).code === "23505") return no(409, `${d.admin} ya tiene una invitación en otra organización.`);
      throw e;
    } finally {
      client.release();
    }
  }

  async cambiarTipo(u: Usuario, id: string, tipo: string) {
    const { rowCount } = await this.pool.query("UPDATE organizaciones SET tipo = $2 WHERE id = $1", [id, tipo]);
    if (!rowCount) return no(404, "No encontrada.");
    await this.historial(u, "cambiar_tipo", id, { tipo });
    return ok(null);
  }

  async suspender(u: Usuario, id: string, suspender: boolean) {
    const { rowCount } = await this.pool.query(
      `UPDATE organizaciones SET suspendida_en = ${suspender ? "coalesce(suspendida_en, now())" : "NULL"} WHERE id = $1`,
      [id],
    );
    if (!rowCount) return no(404, "No encontrada.");
    await this.historial(u, suspender ? "suspender" : "reactivar", id, {});
    return ok(null);
  }

  async uso(mes: string): Promise<UsoMes[]> {
    const { rows } = await this.pool.query(
      `SELECT o.id AS "organizacionId", o.nombre,
              (SELECT count(DISTINCT f.productor_id)::int FROM entregas e JOIN fincas f ON f.id = e.finca_id
               JOIN productores p ON p.id = f.productor_id
               WHERE p.organizacion_id = o.id AND e.anulada_en IS NULL AND to_char(e.fecha - interval '6 hours', 'YYYY-MM') = $1) AS "productoresActivos",
              (SELECT count(*)::int FROM fincas f JOIN productores p ON p.id = f.productor_id
               WHERE p.organizacion_id = o.id AND f.anonimizada_en IS NULL) AS fincas,
              coalesce((SELECT sum(${AREA_OFICIAL("f")}) FROM fincas f JOIN productores p ON p.id = f.productor_id
               WHERE p.organizacion_id = o.id AND f.anonimizada_en IS NULL), 0)::float8 AS hectareas
       FROM organizaciones o WHERE o.eliminada_en IS NULL ORDER BY o.nombre`,
      [mes],
    );
    const cobros = new CobrosPg(this.pool);
    const salida: UsoMes[] = [];
    for (const r of rows) {
      const e: EstadoDeCuenta = await cobros.estadoDeCuenta(r.organizacionId, mes);
      salida.push({
        ...r,
        hectareas: Math.round(r.hectareas * 100) / 100,
        contenedoresMes: e.contenedores.length,
        totalUsd: e.totalUsd,
        sinContrato: e.sinContrato,
        quedanBolsa: e.contratos.length > 0 ? e.contratos.reduce((s, c) => s + c.quedan, 0) : null,
      });
    }
    return salida;
  }

  async estadoDeCuentaCsv(id: string, mes: string) {
    const { rows: [o] } = await this.pool.query<{ nombre: string }>("SELECT nombre FROM organizaciones WHERE id = $1", [id]);
    if (!o) return null;
    const e = await new CobrosPg(this.pool).estadoDeCuenta(id, mes);
    const dia = (d: Date) => d.toISOString().slice(0, 10);
    return csv([
      ["Organización", "Mes", "Concepto", "Código", "Contenedor", "Fecha", "Kg", "En la bolsa", "USD", "Attestation"],
      ...e.contratos
        .filter((r) => r.cuotaEsteMes)
        .map((r) => [o.nombre, mes, `Cuota ${r.contrato.plan} ${r.contrato.inicio} a ${r.contrato.fin}`, "", "", r.contrato.inicio, "", "", r.contrato.cuotaUsd.toFixed(2), ""]),
      ...e.contenedores.map((c) => [
        o.nombre, mes, "Contenedor cerrado", c.codigo ?? "", c.numeroContenedor ?? "", dia(c.fecha), String(c.kg ?? 0),
        c.incluido ? "sí" : "no", c.cobroUsd === null ? "SIN CONTRATO" : c.cobroUsd.toFixed(2), c.attestationUid ?? "",
      ]),
      ...e.ajustes.map((a) => [o.nombre, mes, `Ajuste: ${a.motivo}`, "", "", dia(a.fecha), "", "", (a.montoUsd ?? 0).toFixed(2), ""]),
      [o.nombre, mes, "TOTAL", "", "", "", "", "", e.totalUsd.toFixed(2), ""],
    ]);
  }

  async salud(): Promise<Salud> {
    const { rows: tareas } = await this.pool.query(
      `SELECT t.tarea, c.fin AS ultima, c.ok, c.detalle
       FROM unnest($1::text[]) AS t(tarea)
       LEFT JOIN LATERAL (SELECT fin, ok, detalle FROM corridas_tareas WHERE tarea = t.tarea ORDER BY inicio DESC LIMIT 1) c ON true`,
      [TAREAS],
    );
    const { rows: [a] } = await this.pool.query(
      `SELECT count(*)::int AS pendientes, count(*) FILTER (WHERE error IS NOT NULL)::int AS "conError",
              min(creado_en) AS "masAntigua"
       FROM attestations_pendientes`,
    );
    const { rows: rojas } = await this.pool.query(
      `SELECT o.nombre AS organizacion, count(*)::int AS fincas
       FROM fincas f JOIN productores p ON p.id = f.productor_id JOIN organizaciones o ON o.id = p.organizacion_id
       WHERE f.deforestacion = 'rojo' AND f.anonimizada_en IS NULL GROUP BY 1 ORDER BY 2 DESC`,
    );
    let saldoEth: string | null = null;
    try {
      saldoEth = this.firma ? await this.firma.saldo() : null;
    } catch {
      saldoEth = null;
    }
    return {
      tareas: tareas.map((t) => ({ ...t, ultima: t.ultima ? new Date(t.ultima).toISOString() : null })),
      attestations: { ...a, masAntigua: a.masAntigua ? new Date(a.masAntigua).toISOString() : null },
      firma: { red: this.firma?.red ?? null, saldoEth },
      fincasEnRojo: rojas,
    };
  }

  async solicitudes(): Promise<SolicitudConsola[]> {
    const { rows } = await this.pool.query(
      `SELECT s.id, o.nombre AS organizacion, s.creada_en AS "creadaEn",
              floor(extract(epoch FROM now() - s.creada_en) / 86400)::int AS dias
       FROM solicitudes_eliminacion s LEFT JOIN organizaciones o ON o.id = s.organizacion_id
       WHERE s.estado = 'pendiente' AND (s.organizacion_id IS NULL OR s.creada_en < now() - interval '15 days')
       ORDER BY s.creada_en`,
    );
    return rows.map((r) => ({ ...r, creadaEn: new Date(r.creadaEn).toISOString() }));
  }

  async equipo(id: string): Promise<MiembroEquipo[]> {
    const { rows } = await this.pool.query(
      `SELECT email, rol, usuario_uid IS NOT NULL AS activo FROM invitaciones WHERE organizacion_id = $1
       ORDER BY rol, email`,
      [id],
    );
    return rows;
  }

  async invitar(u: Usuario, id: string, email: string, rolNuevo: string) {
    try {
      const { rowCount } = await this.pool.query(
        `INSERT INTO invitaciones (email, organizacion_id, rol, invitado_por)
         SELECT $1, o.id, $3, $4 FROM organizaciones o WHERE o.id = $2`,
        [email, id, rolNuevo, u.uid],
      );
      if (!rowCount) return no(404, "No encontrada.");
    } catch (e) {
      if ((e as { code?: string }).code === "23505") return no(409, `${email} ya tiene una invitación.`);
      throw e;
    }
    await this.historial(u, "invitar", id, { email, rol: rolNuevo });
    return ok(null);
  }

  async cambiarRol(u: Usuario, id: string, email: string, rolNuevo: string) {
    const { rows: [i] } = await this.pool.query<{ usuarioUid: string | null }>(
      `UPDATE invitaciones SET rol = $3 WHERE organizacion_id = $1 AND email = $2
       RETURNING usuario_uid AS "usuarioUid"`,
      [id, email, rolNuevo],
    );
    if (!i) return no(404, "Esa persona no está en el equipo.");
    await this.historial(u, "cambiar_rol", id, { email, rol: rolNuevo });
    return ok({ usuarioUid: i.usuarioUid });
  }

  async cancelarInvitacion(u: Usuario, id: string, email: string) {
    const { rowCount } = await this.pool.query(
      "DELETE FROM invitaciones WHERE organizacion_id = $1 AND email = $2 AND usuario_uid IS NULL",
      [id, email],
    );
    if (!rowCount) return no(409, "Solo se cancela una invitación que todavía no se aceptó.");
    await this.historial(u, "cancelar_invitacion", id, { email });
    return ok(null);
  }
}
