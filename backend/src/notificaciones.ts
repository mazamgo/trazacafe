import type pg from "pg";
import { z } from "zod";
import type { UsuarioActivo } from "./auth.ts";

/**
 * Notificaciones push (FCM) a los administradores: red de proveedores
 * (invitaciones, ventas, recepciones, vínculos terminados, observaciones) y
 * alertas satelitales. Un aviso que falla nunca rompe la acción que lo causó.
 */

export const dispositivoSchema = z.object({
  token: z.string().trim().min(10).max(4096),
  plataforma: z.enum(["android", "ios", "web"]).default("android"),
});

/** Lo que muestra el celular; `pantalla` es adonde lleva al tocarlo. */
export interface Mensaje {
  titulo: string;
  cuerpo: string;
  pantalla: "clientes" | "proveedores" | "observaciones" | "lotes" | "reportes";
}

/** Envía a esos tokens y devuelve los que FCM da por inválidos (para borrarlos). */
export type EnviarPush = (tokens: string[], m: Mensaje) => Promise<string[]>;

export interface Notificaciones {
  registrar(u: UsuarioActivo, token: string, plataforma: string): Promise<void>;
  /** Al cerrar sesión: el celular deja de recibir avisos de esa persona. */
  baja(token: string, usuarioUid: string): Promise<void>;
  invitacion(vinculoId: string): Promise<void>;
  /** Avisa a la otra organización del vínculo. */
  vinculoTerminado(vinculoId: string, porOrganizacionId: string): Promise<void>;
  loteVendido(loteId: string): Promise<void>;
  loteRecibido(loteId: string): Promise<void>;
  observacion(id: string): Promise<void>;
  respuesta(id: string): Promise<void>;
  /** Fincas que acaban de pasar a amarillo o rojo: un aviso por organización. */
  alertasSatelitales(fincaIds: string[]): Promise<void>;
}

const kg = (n: number) => Number(n).toLocaleString("en-US", { maximumFractionDigits: 0 });
const corto = (t: string, n = 90) => (t.length > n ? `${t.slice(0, n - 1)}…` : t);

export class NotificacionesPg implements Notificaciones {
  constructor(
    private readonly pool: pg.Pool,
    private readonly enviar: EnviarPush,
  ) {}

  async registrar(u: UsuarioActivo, token: string, plataforma: string) {
    await this.pool.query(
      `INSERT INTO dispositivos (token, usuario_uid, organizacion_id, plataforma) VALUES ($1, $2, $3, $4)
       ON CONFLICT (token) DO UPDATE SET usuario_uid = $2, organizacion_id = $3, plataforma = $4, actualizado_en = now()`,
      [token, u.uid, u.organizacionId, plataforma],
    );
  }

  async baja(token: string, usuarioUid: string) {
    await this.pool.query("DELETE FROM dispositivos WHERE token = $1 AND usuario_uid = $2", [token, usuarioUid]);
  }

  /** A los administradores activos de la organización. */
  private async aOrganizacion(organizacionId: string, m: Mensaje) {
    const { rows } = await this.pool.query<{ token: string }>(
      `SELECT d.token FROM dispositivos d
       JOIN invitaciones i ON i.usuario_uid = d.usuario_uid AND i.organizacion_id = d.organizacion_id
       WHERE d.organizacion_id = $1 AND i.rol = 'admin'`,
      [organizacionId],
    );
    if (rows.length === 0) return;
    const invalidos = await this.enviar(rows.map((r) => r.token), m);
    if (invalidos.length > 0) await this.pool.query("DELETE FROM dispositivos WHERE token = ANY($1::text[])", [invalidos]);
  }

  private async vinculo(id: string) {
    const { rows: [v] } = await this.pool.query<{ proveedoraId: string; clienteId: string; proveedora: string; cliente: string }>(
      `SELECT v.proveedora_id AS "proveedoraId", v.cliente_id AS "clienteId", p.nombre AS proveedora, c.nombre AS cliente
       FROM vinculos v JOIN organizaciones p ON p.id = v.proveedora_id JOIN organizaciones c ON c.id = v.cliente_id
       WHERE v.id = $1`,
      [id],
    );
    return v;
  }

  async invitacion(vinculoId: string) {
    const v = await this.vinculo(vinculoId);
    if (!v) return;
    await this.aOrganizacion(v.proveedoraId, {
      titulo: `Invitación de ${v.cliente}`,
      cuerpo: `${v.cliente} te invitó como proveedora en TrazaCafé. Respóndela en Clientes.`,
      pantalla: "clientes",
    });
  }

  async vinculoTerminado(vinculoId: string, porOrganizacionId: string) {
    const v = await this.vinculo(vinculoId);
    if (!v) return;
    const fueCliente = porOrganizacionId === v.clienteId;
    await this.aOrganizacion(fueCliente ? v.proveedoraId : v.clienteId, {
      titulo: "Vínculo terminado",
      cuerpo: `${fueCliente ? v.cliente : v.proveedora} terminó el vínculo con tu organización.`,
      pantalla: fueCliente ? "clientes" : "proveedores",
    });
  }

  private async venta(loteId: string) {
    const { rows: [x] } = await this.pool.query<{
      codigo: string; proveedoraId: string; clienteId: string; proveedora: string; cliente: string;
      kgEnviados: number; kgRecibidos: number | null;
    }>(
      `SELECT l.codigo, l.organizacion_id AS "proveedoraId", v.cliente_id AS "clienteId", p.nombre AS proveedora,
              c.nombre AS cliente, v.kg_enviados::float8 AS "kgEnviados", v.kg_recibidos::float8 AS "kgRecibidos"
       FROM ventas_lotes v JOIN lotes l ON l.id = v.lote_id
       JOIN organizaciones p ON p.id = l.organizacion_id JOIN organizaciones c ON c.id = v.cliente_id
       WHERE v.lote_id = $1`,
      [loteId],
    );
    return x;
  }

  async loteVendido(loteId: string) {
    const x = await this.venta(loteId);
    if (!x) return;
    await this.aOrganizacion(x.clienteId, {
      titulo: "Lote por recibir",
      cuerpo: `${x.proveedora} te envió el lote ${x.codigo} (${kg(x.kgEnviados)} kg). Recíbelo en Proveedores.`,
      pantalla: "proveedores",
    });
  }

  async loteRecibido(loteId: string) {
    const x = await this.venta(loteId);
    if (!x) return;
    await this.aOrganizacion(x.proveedoraId, {
      titulo: "Lote recibido",
      cuerpo: `${x.cliente} recibió el lote ${x.codigo} (${kg(x.kgRecibidos ?? x.kgEnviados)} kg).`,
      pantalla: "lotes",
    });
  }

  private async obs(id: string) {
    const { rows: [o] } = await this.pool.query<{
      proveedoraId: string; clienteId: string; proveedora: string; cliente: string; texto: string; respuesta: string | null;
    }>(
      `SELECT o.proveedora_id AS "proveedoraId", o.cliente_id AS "clienteId", p.nombre AS proveedora, c.nombre AS cliente,
              o.texto, o.respuesta
       FROM observaciones o JOIN organizaciones p ON p.id = o.proveedora_id JOIN organizaciones c ON c.id = o.cliente_id
       WHERE o.id = $1`,
      [id],
    );
    return o;
  }

  async observacion(id: string) {
    const o = await this.obs(id);
    if (!o) return;
    await this.aOrganizacion(o.proveedoraId, {
      titulo: `Observación de ${o.cliente}`,
      cuerpo: corto(o.texto),
      pantalla: "observaciones",
    });
  }

  async respuesta(id: string) {
    const o = await this.obs(id);
    if (!o?.respuesta) return;
    await this.aOrganizacion(o.clienteId, {
      titulo: `${o.proveedora} respondió tu observación`,
      cuerpo: corto(o.respuesta),
      pantalla: "observaciones",
    });
  }

  async alertasSatelitales(fincaIds: string[]) {
    if (fincaIds.length === 0) return;
    const { rows } = await this.pool.query<{ organizacionId: string; nombres: string[]; rojas: number }>(
      `SELECT p.organizacion_id AS "organizacionId", array_agg(f.nombre ORDER BY f.nombre) AS nombres,
              count(*) FILTER (WHERE f.deforestacion = 'rojo')::int AS rojas
       FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE f.id = ANY($1::uuid[]) AND f.deforestacion IN ('amarillo', 'rojo')
       GROUP BY 1`,
      [fincaIds],
    );
    for (const r of rows) {
      const n = r.nombres.length;
      await this.aOrganizacion(r.organizacionId, {
        titulo: r.rojas > 0 ? "Alerta satelital: finca en rojo" : "Alerta satelital",
        cuerpo:
          `${n === 1 ? "Una finca pasó" : `${n} fincas pasaron`} a ${r.rojas > 0 ? "rojo o amarillo" : "amarillo"}: ` +
          `${r.nombres.slice(0, 3).join(", ")}${n > 3 ? "…" : ""}. Revísalas en Reportes.`,
        pantalla: "reportes",
      });
    }
  }
}
