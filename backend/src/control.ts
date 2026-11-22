import type pg from "pg";
import { z } from "zod";
import type { UsuarioActivo } from "./auth.ts";
import type { Resultado } from "./correcciones.ts";
import { ALIAS_FINCA, AREA_OFICIAL, desdeGeometria } from "./repo.ts";
import { fechaPasada } from "./sync.ts";

/**
 * Visitas de control de la exportadora (Fase 2b, paso 5). La cooperativa da
 * permiso por vínculo; la exportadora elige fincas de los lotes que le
 * vendieron (muestreo) y sus técnicos las visitan desde el celular. La visita
 * queda en `verificaciones` con `organizacion_id` = la exportadora, se firma
 * como cualquier visita y no cuenta como la visita de la cooperativa.
 */

export const permisoVisitasSchema = z.object({ permiteVisitas: z.boolean() });
export const muestreoSchema = z.object({ fincaId: z.uuid() });
export const visitaControlSchema = z.object({
  id: z.uuid(),
  fincaId: z.uuid(),
  fecha: fechaPasada("la visita"),
  /** ¿El lindero en el campo no coincide con el registrado? */
  linderoCambio: z.boolean(),
  nota: z.string().trim().max(2000).nullish(),
});
export type VisitaControl = z.infer<typeof visitaControlSchema>;

/** Finca de un lote recibido, para elegirla en el muestreo (exportadora). */
export interface FincaMuestreo {
  id: string;
  /** Alias ("Finca 3F2A") si la cooperativa no comparte nombres. */
  nombre: string;
  productorNombre: string | null;
  comunidad: string | null;
  temporadaId: string;
  temporadaNombre: string;
  deforestacion: string;
  elegida: boolean;
  controles: number;
}

/** Finca que deben visitar los técnicos de la exportadora (sin señal). */
export interface FincaControl {
  id: string;
  nombre: string;
  productorNombre: string | null;
  comunidad: string | null;
  proveedor: string;
  cultivo: string;
  coordenadas: [number, number][];
  areaOficialHa: number;
  temporadaNombre: string;
  /** ¿Ya tiene visita de control de esta organización en la temporada? */
  visitada: boolean;
}

/** Visita de control hecha, para que la vean las dos organizaciones. */
export interface Control {
  id: string;
  fincaId: string;
  finca: string;
  fecha: string;
  linderoCambio: boolean;
  nota: string | null;
  por: string | null;
}

export interface Controles {
  /** Cooperativa: da o quita el permiso en un vínculo activo. */
  permitirVisitas(u: UsuarioActivo, vinculoId: string, permite: boolean): Promise<Resultado<null>>;
  /** Exportadora: fincas de los lotes recibidos de esa proveedora, con las elegidas. */
  muestreo(organizacionId: string, vinculoId: string): Promise<Resultado<{ permiteVisitas: boolean; fincas: FincaMuestreo[] }>>;
  elegir(u: UsuarioActivo, vinculoId: string, fincaId: string, elegir: boolean): Promise<Resultado<null>>;
  /** Técnicos de la exportadora: lo que hay que visitar. */
  pendientes(organizacionId: string): Promise<FincaControl[]>;
  registrar(u: UsuarioActivo, v: VisitaControl): Promise<Resultado<null>>;
  /** Visitas de control de un vínculo; lo ven la exportadora y la cooperativa. */
  controles(organizacionId: string, vinculoId: string): Promise<Resultado<Control[]>>;
}

const ok = <T>(valor: T): Resultado<T> => ({ ok: true, valor });
const no = (status: 403 | 404 | 409 | 422, mensaje: string): Resultado<never> => ({ ok: false, status, mensaje });

/** Fincas de los lotes que la proveedora del vínculo le vendió al cliente, con su temporada. */
const FINCAS_RECIBIDAS = `
  SELECT DISTINCT ON (e.finca_id) e.finca_id, l.temporada_id
  FROM ventas_lotes v JOIN lotes l ON l.id = v.lote_id
  JOIN lote_entregas le ON le.lote_id = l.id JOIN entregas e ON e.id = le.entrega_id
  WHERE v.vinculo_id = $1 AND e.anulada_en IS NULL
  ORDER BY e.finca_id, v.fecha_envio DESC`;

export class ControlesPg implements Controles {
  constructor(private readonly pool: pg.Pool) {}

  private async vinculo(id: string) {
    const { rows: [v] } = await this.pool.query<{
      proveedoraId: string; clienteId: string; estado: string; permiteVisitas: boolean; comparteNombres: boolean;
    }>(
      `SELECT proveedora_id AS "proveedoraId", cliente_id AS "clienteId", estado, permite_visitas AS "permiteVisitas",
              comparte_nombres AS "comparteNombres"
       FROM vinculos WHERE id = $1`,
      [id],
    );
    return v;
  }

  async permitirVisitas(u: UsuarioActivo, vinculoId: string, permite: boolean) {
    const v = await this.vinculo(vinculoId);
    if (!v || v.proveedoraId !== u.organizacionId) return no(404, "No encontrado.");
    if (v.estado !== "activo") return no(409, "El vínculo no está activo.");
    await this.pool.query("UPDATE vinculos SET permite_visitas = $2 WHERE id = $1", [vinculoId, permite]);
    // Sin permiso, el muestreo se vacía: los técnicos dejan de ver esas fincas.
    if (!permite) await this.pool.query("DELETE FROM muestreos WHERE vinculo_id = $1", [vinculoId]);
    return ok(null);
  }

  async muestreo(organizacionId: string, vinculoId: string) {
    const v = await this.vinculo(vinculoId);
    if (!v || v.clienteId !== organizacionId) return no(404, "No encontrado.");
    const { rows } = await this.pool.query<FincaMuestreo>(
      `WITH fr AS (${FINCAS_RECIBIDAS})
       SELECT f.id, CASE WHEN $2 THEN f.nombre ELSE ${ALIAS_FINCA("f")} END AS nombre,
              CASE WHEN $2 THEN p.nombre END AS "productorNombre", p.comunidad,
              fr.temporada_id AS "temporadaId", t.nombre AS "temporadaNombre", f.deforestacion,
              EXISTS (SELECT 1 FROM muestreos m WHERE m.vinculo_id = $1 AND m.finca_id = f.id AND m.temporada_id = fr.temporada_id) AS elegida,
              (SELECT count(*)::int FROM verificaciones vv
               WHERE vv.finca_id = f.id AND vv.organizacion_id = $3 AND vv.anulada_en IS NULL) AS controles
       FROM fr JOIN fincas f ON f.id = fr.finca_id JOIN productores p ON p.id = f.productor_id
       JOIN temporadas t ON t.id = fr.temporada_id
       ORDER BY 2`,
      [vinculoId, v.comparteNombres, organizacionId],
    );
    return ok({ permiteVisitas: v.permiteVisitas, fincas: rows });
  }

  async elegir(u: UsuarioActivo, vinculoId: string, fincaId: string, elegir: boolean) {
    const v = await this.vinculo(vinculoId);
    if (!v || v.clienteId !== u.organizacionId) return no(404, "No encontrado.");
    if (!elegir) {
      await this.pool.query("DELETE FROM muestreos WHERE vinculo_id = $1 AND finca_id = $2", [vinculoId, fincaId]);
      return ok(null);
    }
    if (v.estado !== "activo") return no(409, "El vínculo no está activo.");
    if (!v.permiteVisitas) return no(409, "La cooperativa no ha permitido visitas de control.");
    const { rows: [fr] } = await this.pool.query<{ temporada_id: string }>(
      `SELECT temporada_id FROM (${FINCAS_RECIBIDAS}) fr WHERE fr.finca_id = $2`,
      [vinculoId, fincaId],
    );
    if (!fr) return no(422, "Esa finca no es de un lote que te vendió esta cooperativa.");
    await this.pool.query(
      `INSERT INTO muestreos (vinculo_id, finca_id, temporada_id, asignado_por) VALUES ($1, $2, $3, $4)
       ON CONFLICT DO NOTHING`,
      [vinculoId, fincaId, fr.temporada_id, u.uid],
    );
    return ok(null);
  }

  async pendientes(organizacionId: string): Promise<FincaControl[]> {
    const { rows } = await this.pool.query(
      `SELECT f.id, CASE WHEN vi.comparte_nombres THEN f.nombre ELSE ${ALIAS_FINCA("f")} END AS nombre,
              CASE WHEN vi.comparte_nombres THEN p.nombre END AS "productorNombre", p.comunidad,
              o.nombre AS proveedor, f.cultivo, ST_AsGeoJSON(f.geom, 15)::json AS geom,
              ${AREA_OFICIAL("f")}::float8 AS "areaOficialHa", t.nombre AS "temporadaNombre",
              EXISTS (SELECT 1 FROM verificaciones vv
                      WHERE vv.finca_id = f.id AND vv.organizacion_id = $1 AND vv.temporada_id = m.temporada_id
                        AND vv.anulada_en IS NULL) AS visitada
       FROM muestreos m JOIN vinculos vi ON vi.id = m.vinculo_id
       JOIN fincas f ON f.id = m.finca_id JOIN productores p ON p.id = f.productor_id
       JOIN organizaciones o ON o.id = vi.proveedora_id JOIN temporadas t ON t.id = m.temporada_id
       WHERE vi.cliente_id = $1 AND vi.estado = 'activo' AND vi.permite_visitas AND f.anonimizada_en IS NULL
       ORDER BY o.nombre, 2`,
      [organizacionId],
    );
    return rows.map(({ geom, ...f }) => ({ ...f, coordenadas: desdeGeometria(geom) }));
  }

  async registrar(u: UsuarioActivo, v: VisitaControl) {
    const { rows: [m] } = await this.pool.query<{ temporada_id: string }>(
      `SELECT m.temporada_id FROM muestreos m JOIN vinculos vi ON vi.id = m.vinculo_id
       WHERE m.finca_id = $1 AND vi.cliente_id = $2 AND vi.estado = 'activo' AND vi.permite_visitas
       ORDER BY m.asignado_en DESC LIMIT 1`,
      [v.fincaId, u.organizacionId],
    );
    if (!m) return no(403, "Esa finca no está en las visitas de control de tu organización.");
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const { rowCount } = await client.query(
        `INSERT INTO verificaciones (id, finca_id, temporada_id, fecha, lindero_cambio, version_finca, nota, creado_por, organizacion_id)
         SELECT $1, f.id, $3, $4, $5, f.version_actual, $6, $7, $8 FROM fincas f WHERE f.id = $2
         ON CONFLICT (id) DO NOTHING`,
        [v.id, v.fincaId, m.temporada_id, v.fecha, v.linderoCambio, v.nota ?? null, u.uid, u.organizacionId],
      );
      if (rowCount) {
        await client.query(
          "INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Verificacion', $1) ON CONFLICT DO NOTHING",
          [v.id],
        );
      }
      await client.query("COMMIT");
      return ok(null);
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async controles(organizacionId: string, vinculoId: string) {
    const v = await this.vinculo(vinculoId);
    if (!v || (v.clienteId !== organizacionId && v.proveedoraId !== organizacionId)) return no(404, "No encontrado.");
    const nombres = v.comparteNombres || v.proveedoraId === organizacionId;
    const { rows } = await this.pool.query(
      `SELECT vv.id, f.id AS "fincaId", CASE WHEN $3 THEN f.nombre ELSE ${ALIAS_FINCA("f")} END AS finca,
              vv.fecha, vv.lindero_cambio AS "linderoCambio", vv.nota, i.email AS por
       FROM verificaciones vv JOIN fincas f ON f.id = vv.finca_id JOIN productores p ON p.id = f.productor_id
       LEFT JOIN invitaciones i ON i.usuario_uid = vv.creado_por AND i.organizacion_id = vv.organizacion_id
       WHERE vv.organizacion_id = $1 AND p.organizacion_id = $2 AND vv.anulada_en IS NULL
       ORDER BY vv.fecha DESC`,
      [v.clienteId, v.proveedoraId, nombres],
    );
    return ok(rows.map((r) => ({ ...r, fecha: new Date(r.fecha).toISOString() })) as Control[]);
  }
}
