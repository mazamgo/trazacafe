import type pg from "pg";
import { z } from "zod";
import type { UsuarioActivo } from "./auth.ts";
import type { Resultado } from "./correcciones.ts";
import type { FincaDePaquete, Paquete } from "./repo.ts";

/**
 * Portal del importador (Fase 2c): la exportadora invita a su comprador, le
 * asigna contenedores cerrados y él ve solo esos, sin datos personales,
 * descarga su paquete EUDR, anota la referencia de su DDS y recibe alertas
 * si una finca de origen pasa a amarillo o rojo después de la compra.
 */

export const invitarCompradorSchema = z.object({ email: z.email().transform((e) => e.toLowerCase()) });
export const asignarSchema = z.object({ compradorId: z.uuid() });
export const ddsSchema = z.object({ ddsRef: z.string().trim().min(1).max(60) });

export interface Comprador {
  id: string;
  /** Papel de quien consulta. */
  soy: "exportadora" | "importador";
  organizacion: { id: string; nombre: string };
  estado: "pendiente" | "activo" | "rechazado" | "terminado";
  invitadoEn: string;
  contenedores: number;
}

/** Contenedor comprado, como lo ve el importador. */
export interface ContenedorComprado {
  id: string;
  codigo: string;
  contenedor: string | null;
  exportadora: string;
  cultivo: string;
  destino: string;
  fechaEmbarque: string | null;
  kg: number;
  attestationUid: string | null;
  ddsRef: string | null;
  vendidoEn: string;
  fincas: number;
  fincasVerdes: number;
  alertas: number;
}

export interface AlertaComprador {
  id: number;
  contenedor: string;
  codigo: string;
  /** Alias de la finca ("Finca 3F2A"): el importador no ve nombres. */
  finca: string;
  resultado: "amarillo" | "rojo";
  detectadaEn: string;
}

export interface Compradores {
  lista(organizacionId: string): Promise<Comprador[]>;
  invitar(u: UsuarioActivo, email: string): Promise<Resultado<Comprador>>;
  responder(u: UsuarioActivo, id: string, aceptar: boolean): Promise<Resultado<null>>;
  terminar(u: UsuarioActivo, id: string): Promise<Resultado<null>>;
  /** Exportadora: asigna un contenedor cerrado a un comprador activo, o lo libera. */
  asignar(u: UsuarioActivo, exportacionId: string, compradorId: string | null): Promise<Resultado<null>>;
  contenedores(organizacionId: string): Promise<ContenedorComprado[]>;
  /** De quién es el contenedor comprado (para armar su paquete), o `null`. */
  exportadoraDe(importadorId: string, exportacionId: string): Promise<string | null>;
  anotarDds(u: UsuarioActivo, exportacionId: string, ddsRef: string): Promise<Resultado<null>>;
  alertas(organizacionId: string): Promise<AlertaComprador[]>;
  /** Tras el chequeo diario: fincas que empeoraron en contenedores vendidos. */
  registrarAlertas(fincaIds: string[]): Promise<number>;
  /** Alertas sin avisar, agrupadas por importador con los correos de sus administradores. */
  alertasPorAvisar(): Promise<{ correos: string[]; alertas: AlertaComprador[] }[]>;
  marcarAvisadas(ids: number[]): Promise<void>;
}

const ok = <T>(valor: T): Resultado<T> => ({ ok: true, valor });
const no = (status: 403 | 404 | 409 | 422, mensaje: string): Resultado<never> => ({ ok: false, status, mensaje });
const aliasFinca = (id: string) => `Finca ${id.slice(0, 4).toUpperCase()}`;

/** El paquete como lo ve el importador: sin nombres de productores ni de fincas. */
export function paqueteParaComprador(p: Paquete): Paquete {
  return {
    ...p,
    fincas: p.fincas.map((f): FincaDePaquete => ({ ...f, nombre: aliasFinca(f.id), productorNombre: null })),
  };
}

export class CompradoresPg implements Compradores {
  constructor(private readonly pool: pg.Pool) {}

  async lista(organizacionId: string): Promise<Comprador[]> {
    const { rows } = await this.pool.query(
      `SELECT c.id, CASE WHEN c.exportadora_id = $1 THEN 'exportadora' ELSE 'importador' END AS soy,
              json_build_object('id', o.id, 'nombre', o.nombre) AS organizacion, c.estado, c.invitado_en AS "invitadoEn",
              (SELECT count(*)::int FROM ventas_contenedores v WHERE v.comprador_id = c.id) AS contenedores
       FROM compradores c
       JOIN organizaciones o ON o.id = CASE WHEN c.exportadora_id = $1 THEN c.importador_id ELSE c.exportadora_id END
       WHERE c.exportadora_id = $1 OR c.importador_id = $1
       ORDER BY c.estado IN ('pendiente', 'activo') DESC, o.nombre`,
      [organizacionId],
    );
    return rows.map((r) => ({ ...r, invitadoEn: new Date(r.invitadoEn).toISOString() }));
  }

  async invitar(u: UsuarioActivo, email: string) {
    const { rows: [propia] } = await this.pool.query<{ tipo: string }>("SELECT tipo FROM organizaciones WHERE id = $1", [
      u.organizacionId,
    ]);
    if (!propia || !["exportadora", "beneficio"].includes(propia.tipo)) {
      return no(403, "Solo una exportadora o un beneficio invita compradores.");
    }
    const { rows: [imp] } = await this.pool.query<{ id: string; tipo: string }>(
      `SELECT o.id, o.tipo FROM invitaciones i JOIN organizaciones o ON o.id = i.organizacion_id
       WHERE i.email = $1 AND i.rol = 'admin' AND i.usuario_uid IS NOT NULL AND o.eliminada_en IS NULL`,
      [email],
    );
    if (!imp) {
      return no(404, "Ese correo no es de un administrador activo en TrazaCafé. El importador debe estar dado de alta y haber entrado al panel.");
    }
    if (imp.tipo !== "importador") return no(422, "Ese correo es de una organización que no es importadora.");
    const id = crypto.randomUUID();
    try {
      await this.pool.query("INSERT INTO compradores (id, exportadora_id, importador_id, invitado_por) VALUES ($1, $2, $3, $4)", [
        id,
        u.organizacionId,
        imp.id,
        u.uid,
      ]);
    } catch (e) {
      if ((e as { constraint?: string }).constraint === "compradores_vigente_unico") {
        return no(409, "Ya hay una invitación o un vínculo con ese importador.");
      }
      throw e;
    }
    return ok((await this.lista(u.organizacionId)).find((c) => c.id === id)!);
  }

  async responder(u: UsuarioActivo, id: string, aceptar: boolean) {
    const { rowCount } = await this.pool.query(
      `UPDATE compradores SET estado = $3, respondido_en = now()
       WHERE id = $1 AND importador_id = $2 AND estado = 'pendiente'`,
      [id, u.organizacionId, aceptar ? "activo" : "rechazado"],
    );
    return rowCount ? ok(null) : no(404, "No hay una invitación pendiente con ese id.");
  }

  async terminar(u: UsuarioActivo, id: string) {
    const { rowCount } = await this.pool.query(
      `UPDATE compradores SET estado = 'terminado', terminado_en = now()
       WHERE id = $1 AND (exportadora_id = $2 OR importador_id = $2) AND estado IN ('pendiente', 'activo')`,
      [id, u.organizacionId],
    );
    // Lo ya asignado se conserva: el importador lo necesita para su DDS y su archivo.
    return rowCount ? ok(null) : no(404, "No encontrado.");
  }

  async asignar(u: UsuarioActivo, exportacionId: string, compradorId: string | null) {
    const { rows: [x] } = await this.pool.query<{ estado: string; vendido: boolean }>(
      `SELECT x.estado, EXISTS (SELECT 1 FROM ventas_contenedores v WHERE v.exportacion_id = x.id) AS vendido
       FROM exportaciones x WHERE x.id = $1 AND x.organizacion_id = $2`,
      [exportacionId, u.organizacionId],
    );
    if (!x) return no(404, "No encontrado.");
    if (compradorId === null) {
      const { rowCount } = await this.pool.query(
        "DELETE FROM ventas_contenedores WHERE exportacion_id = $1 AND dds_ref IS NULL",
        [exportacionId],
      );
      return rowCount || !x.vendido ? ok(null) : no(409, "El comprador ya anotó su DDS: el contenedor no se puede liberar.");
    }
    if (x.estado !== "cerrada") return no(409, "Solo se asigna un contenedor cerrado (con su paquete EUDR completo).");
    if (x.vendido) return no(409, "El contenedor ya está asignado a un comprador.");
    const { rows: [c] } = await this.pool.query<{ importador_id: string }>(
      "SELECT importador_id FROM compradores WHERE id = $1 AND exportadora_id = $2 AND estado = 'activo'",
      [compradorId, u.organizacionId],
    );
    if (!c) return no(422, "Ese comprador no está activo.");
    await this.pool.query(
      `INSERT INTO ventas_contenedores (exportacion_id, comprador_id, importador_id, vendido_por) VALUES ($1, $2, $3, $4)`,
      [exportacionId, compradorId, c.importador_id, u.uid],
    );
    return ok(null);
  }

  async contenedores(organizacionId: string): Promise<ContenedorComprado[]> {
    const { rows } = await this.pool.query(
      `SELECT x.id, x.codigo, x.contenedor, o.nombre AS exportadora, x.cultivo, x.destino,
              to_char(x.fecha_embarque, 'YYYY-MM-DD') AS "fechaEmbarque",
              coalesce((SELECT sum(kg_en_contenedor(el.lote_id)) FROM exportacion_lotes el WHERE el.exportacion_id = x.id), 0)::float8 AS kg,
              x.attestation_uid AS "attestationUid", coalesce(v.dds_ref, x.dds_ref) AS "ddsRef", v.vendido_en AS "vendidoEn",
              (SELECT count(DISTINCT e.finca_id)::int FROM exportacion_lotes el JOIN lote_entregas le ON le.lote_id = el.lote_id
               JOIN entregas e ON e.id = le.entrega_id WHERE el.exportacion_id = x.id) AS fincas,
              (SELECT count(DISTINCT e.finca_id)::int FROM exportacion_lotes el JOIN lote_entregas le ON le.lote_id = el.lote_id
               JOIN entregas e ON e.id = le.entrega_id JOIN fincas f ON f.id = e.finca_id
               WHERE el.exportacion_id = x.id AND f.deforestacion = 'verde') AS "fincasVerdes",
              (SELECT count(*)::int FROM alertas_comprador a WHERE a.exportacion_id = x.id) AS alertas
       FROM ventas_contenedores v JOIN exportaciones x ON x.id = v.exportacion_id
       JOIN organizaciones o ON o.id = x.organizacion_id
       WHERE v.importador_id = $1
       ORDER BY v.vendido_en DESC`,
      [organizacionId],
    );
    return rows.map((r) => ({ ...r, vendidoEn: new Date(r.vendidoEn).toISOString() }));
  }

  async exportadoraDe(importadorId: string, exportacionId: string) {
    const { rows: [r] } = await this.pool.query<{ organizacion_id: string }>(
      `SELECT x.organizacion_id FROM ventas_contenedores v JOIN exportaciones x ON x.id = v.exportacion_id
       WHERE v.exportacion_id = $1 AND v.importador_id = $2`,
      [exportacionId, importadorId],
    );
    return r?.organizacion_id ?? null;
  }

  async anotarDds(u: UsuarioActivo, exportacionId: string, ddsRef: string) {
    const { rowCount } = await this.pool.query(
      "UPDATE ventas_contenedores SET dds_ref = $3, dds_en = now() WHERE exportacion_id = $1 AND importador_id = $2",
      [exportacionId, u.organizacionId, ddsRef],
    );
    if (!rowCount) return no(404, "No encontrado.");
    // Si la exportadora todavía no la anotó, también va al contenedor (y a su firma).
    await this.pool.query("UPDATE exportaciones SET dds_ref = $2 WHERE id = $1 AND dds_ref IS NULL", [exportacionId, ddsRef]);
    return ok(null);
  }

  private async alertasDonde(condicion: string, params: unknown[]): Promise<(AlertaComprador & { importadorId: string })[]> {
    const { rows } = await this.pool.query(
      `SELECT a.id, coalesce(x.contenedor, x.codigo) AS contenedor, x.codigo, a.finca_id::text AS "fincaId",
              a.resultado, a.detectada_en AS "detectadaEn", v.importador_id AS "importadorId"
       FROM alertas_comprador a JOIN exportaciones x ON x.id = a.exportacion_id
       JOIN ventas_contenedores v ON v.exportacion_id = a.exportacion_id
       WHERE ${condicion}
       ORDER BY a.detectada_en DESC`,
      params,
    );
    return rows.map(({ fincaId, ...r }) => ({ ...r, finca: aliasFinca(fincaId), detectadaEn: new Date(r.detectadaEn).toISOString() }));
  }

  async alertas(organizacionId: string): Promise<AlertaComprador[]> {
    return (await this.alertasDonde("v.importador_id = $1", [organizacionId])).map(({ importadorId: _, ...a }) => a);
  }

  async registrarAlertas(fincaIds: string[]) {
    if (fincaIds.length === 0) return 0;
    const { rowCount } = await this.pool.query(
      `INSERT INTO alertas_comprador (exportacion_id, finca_id, resultado)
       SELECT DISTINCT v.exportacion_id, f.id, f.deforestacion
       FROM fincas f JOIN entregas e ON e.finca_id = f.id JOIN lote_entregas le ON le.entrega_id = e.id
       JOIN exportacion_lotes el ON el.lote_id = le.lote_id JOIN ventas_contenedores v ON v.exportacion_id = el.exportacion_id
       WHERE f.id = ANY($1::uuid[]) AND f.deforestacion IN ('amarillo', 'rojo')
       ON CONFLICT DO NOTHING`,
      [fincaIds],
    );
    return rowCount ?? 0;
  }

  async alertasPorAvisar() {
    const pendientes = await this.alertasDonde("a.avisado_en IS NULL", []);
    const porImportador = new Map<string, AlertaComprador[]>();
    for (const { importadorId, ...a } of pendientes) porImportador.set(importadorId, [...(porImportador.get(importadorId) ?? []), a]);
    const salida: { correos: string[]; alertas: AlertaComprador[] }[] = [];
    for (const [importadorId, alertas] of porImportador) {
      const { rows } = await this.pool.query<{ email: string }>(
        "SELECT email FROM invitaciones WHERE organizacion_id = $1 AND rol = 'admin' AND usuario_uid IS NOT NULL",
        [importadorId],
      );
      salida.push({ correos: rows.map((r) => r.email), alertas });
    }
    return salida;
  }

  async marcarAvisadas(ids: number[]) {
    if (ids.length > 0) await this.pool.query("UPDATE alertas_comprador SET avisado_en = now() WHERE id = ANY($1::bigint[])", [ids]);
  }
}

/** Envía un correo. `null` mientras no haya servicio de correo configurado. */
export type Correo = (para: string[], asunto: string, texto: string) => Promise<void>;

/** Texto del correo de alertas para un importador. */
export function correoAlertas(alertas: AlertaComprador[]): { asunto: string; texto: string } {
  const rojas = alertas.filter((a) => a.resultado === "rojo").length;
  return {
    asunto: `TrazaCafé: ${alertas.length} ${alertas.length === 1 ? "alerta satelital" : "alertas satelitales"} en sus contenedores`,
    texto: [
      rojas > 0
        ? "Una o más fincas de origen de sus contenedores muestran pérdida de bosque (rojo) en el último chequeo satelital."
        : "Una o más fincas de origen de sus contenedores tienen una alerta para revisar (amarillo) en el último chequeo satelital.",
      "",
      ...alertas.map((a) => `- ${a.contenedor} (${a.codigo}): ${a.finca}, ${a.resultado === "rojo" ? "rojo" : "amarillo"}, ${a.detectadaEn.slice(0, 10)}`),
      "",
      "Detalle en el panel: https://trazacafe-dev.web.app/panel",
      "Esta información sirve para su evaluación y mitigación de riesgo (EUDR, art. 10 y 11).",
    ].join("\n"),
  };
}
