import { cultivo, estadoValido } from "@trazacafe/eudr-eas-schemas";
import type pg from "pg";
import { z } from "zod";
import type { UsuarioActivo } from "./auth.ts";
import { evaluarLote, type Aviso } from "./lotes.ts";
import { PgRepo, TEMPORADA_DE } from "./repo.ts";
import { fechaPasada, normalizarCedula } from "./sync.ts";

export { normalizarCedula };

/**
 * Correcciones de datos con errores (un cero de más, la fecha equivocada,
 * un nombre mal escrito) mientras no estén sellados: en un lote, en un
 * contenedor o firmados en la blockchain. Cada corrección deja historial en
 * la tabla `correcciones`. Las entregas y visitas no se borran: se anulan.
 *
 * Reglas (plan de correcciones):
 * - cada técnico corrige lo que él registró; el administrador, todo;
 * - motivo obligatorio al corregir kg, áreas y fechas, y al anular.
 */

const motivo = z.string().trim().min(3, "Escribe el motivo (al menos 3 letras)").max(300);
/** Refinamiento: si cambia alguno de [campos], el motivo es obligatorio. */
function conMotivo<T extends { motivo?: string }>(
  campos: (keyof T)[],
): [(x: T) => boolean, { message: string; path: PropertyKey[] }] {
  return [
    (x) => !campos.some((c) => x[c] !== undefined) || !!x.motivo,
    { message: "Escribe el motivo de la corrección", path: ["motivo"] },
  ];
}

/** Refinamiento: al menos uno de [campos] viene en la corrección. */
function algo<T extends object>(campos: (keyof T)[]): [(x: T) => boolean, { message: string }] {
  return [(x) => campos.some((c) => x[c] !== undefined), { message: "Nada que corregir" }];
}

export const correccionEntregaSchema = z
  .object({
    kg: z.number().positive().max(20_000).optional(),
    estado: z.string().regex(/^[a-z_]+$/).optional(),
    fecha: fechaPasada("la entrega").optional(),
    motivo: motivo.optional(),
  })
  .refine(...algo<{ kg?: number; estado?: string; fecha?: string }>(["kg", "estado", "fecha"]))
  .refine(...conMotivo<{ kg?: number; fecha?: string; motivo?: string }>(["kg", "fecha"]));
export type CorreccionEntrega = z.infer<typeof correccionEntregaSchema>;

export const anulacionSchema = z.object({ motivo });

export const correccionLoteSchema = z
  .object({
    kg: z.number().positive().max(1_000_000).optional(),
    codigo: z.string().trim().min(1).max(40).optional(),
    beneficio: z.string().trim().min(1).max(80).optional(),
    proceso: z.string().trim().max(40).nullable().optional(),
    motivo: motivo.optional(),
  })
  .refine(...algo<Record<string, unknown>>(["kg", "codigo", "beneficio", "proceso"]))
  .refine(...conMotivo<{ kg?: number; motivo?: string }>(["kg"]));
export type CorreccionLote = z.infer<typeof correccionLoteSchema>;

export const correccionProductorSchema = z
  .object({
    nombre: z.string().trim().min(1).max(120).optional(),
    cedula: z.string().trim().max(20).nullable().optional(),
    comunidad: z.string().trim().max(120).nullable().optional(),
  })
  .refine(...algo<Record<string, unknown>>(["nombre", "cedula", "comunidad"]))
  .refine((x) => !x.cedula || normalizarCedula(x.cedula) !== null, {
    path: ["cedula"],
    message: "La cédula debe tener el formato 001-010190-0001A",
  });
export type CorreccionProductor = z.infer<typeof correccionProductorSchema>;

export const correccionFincaSchema = z
  .object({
    nombre: z.string().trim().min(1).max(120).optional(),
    /** Solo fincas de un punto (menos de 4 ha); en un polígono el área sale del lindero. */
    areaHa: z.number().positive().lt(4, "Fincas de 4 ha o más necesitan polígono (EUDR)").optional(),
    motivo: motivo.optional(),
  })
  .refine(...algo<Record<string, unknown>>(["nombre", "areaHa"]))
  .refine(...conMotivo<{ areaHa?: number; motivo?: string }>(["areaHa"]));
export type CorreccionFinca = z.infer<typeof correccionFincaSchema>;

export const correccionVisitaSchema = z
  .object({
    nota: z.string().max(2000).nullable().optional(),
    fecha: fechaPasada("la visita").optional(),
    motivo: motivo.optional(),
  })
  .refine(...algo<Record<string, unknown>>(["nota", "fecha"]))
  .refine(...conMotivo<{ fecha?: string; motivo?: string }>(["fecha"]));
export type CorreccionVisita = z.infer<typeof correccionVisitaSchema>;

export const correccionTemporadaSchema = z
  .object({
    nombre: z.string().trim().min(1).max(40).optional(),
    inicio: z.iso.date().optional(),
    fin: z.iso.date().optional(),
    motivo: motivo.optional(),
  })
  .refine(...algo<Record<string, unknown>>(["nombre", "inicio", "fin"]))
  .refine(...conMotivo<{ inicio?: string; fin?: string; motivo?: string }>(["inicio", "fin"]));
export type CorreccionTemporada = z.infer<typeof correccionTemporadaSchema>;

export type Resultado<T = null> = { ok: true; valor: T } | { ok: false; status: 403 | 404 | 409 | 422; mensaje: string };
const ok = <T>(valor: T): Resultado<T> => ({ ok: true, valor });
const no = (status: 403 | 404 | 409 | 422, mensaje: string): Resultado<never> => ({ ok: false, status, mensaje });

/** `null` si puede corregir; si no, el mensaje. */
export function sinPermiso(u: Pick<UsuarioActivo, "uid" | "rol">, creadoPor: string | null): string | null {
  return u.rol === "admin" || u.uid === creadoPor ? null : "Solo quien lo registró o un administrador puede corregirlo.";
}

/** Por qué una entrega ya no se puede corregir ni anular, o `null`. */
export function entregaSellada(e: { anulada: boolean; loteCodigo: string | null; atestada: boolean }): string | null {
  if (e.anulada) return "La entrega ya está anulada.";
  if (e.loteCodigo) return `La entrega está en el lote ${e.loteCodigo}; para corregirla, primero deshaz el lote.`;
  if (e.atestada) return "La entrega ya está firmada en la blockchain; no se puede corregir.";
  return null;
}

/** Por qué una visita ya no permite cambiar la fecha ni anularse, o `null`. La nota siempre se puede corregir. */
export function visitaSellada(v: { anulada: boolean; atestada: boolean; linderoCambio: boolean }): string | null {
  if (v.anulada) return "La visita ya está anulada.";
  if (v.atestada) return "La visita ya está firmada en la blockchain.";
  if (v.linderoCambio) return "Esta visita registró un lindero nuevo: no se puede cambiar su fecha ni anularla.";
  return null;
}

/** Solo los campos que cambiaron, con su valor antes y después (para el historial). */
export function diferencias(antes: Record<string, unknown>, despues: Record<string, unknown>) {
  const a: Record<string, unknown> = {};
  const d: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(despues)) {
    if (v === undefined) continue;
    if (JSON.stringify(antes[k] ?? null) !== JSON.stringify(v)) {
      a[k] = antes[k] ?? null;
      d[k] = v;
    }
  }
  return { antes: a, despues: d, hay: Object.keys(d).length > 0 };
}

export interface EntregaCorregida {
  id: string;
  kg: number;
  estado: string;
  fecha: string;
  temporadaId: string | null;
}

export interface Correcciones {
  corregirEntrega(u: UsuarioActivo, id: string, c: CorreccionEntrega): Promise<Resultado<EntregaCorregida>>;
  anularEntrega(u: UsuarioActivo, id: string, motivo: string): Promise<Resultado>;
  corregirLote(u: UsuarioActivo, id: string, c: CorreccionLote): Promise<Resultado>;
  corregirProductor(u: UsuarioActivo, id: string, c: CorreccionProductor): Promise<Resultado>;
  corregirFinca(u: UsuarioActivo, id: string, c: CorreccionFinca): Promise<Resultado>;
  /** Devuelve la ruta del archivo en Storage para borrarlo también. */
  eliminarFoto(u: UsuarioActivo, id: string): Promise<Resultado<{ storagePath: string | null }>>;
  corregirVerificacion(u: UsuarioActivo, id: string, c: CorreccionVisita): Promise<Resultado>;
  anularVerificacion(u: UsuarioActivo, id: string, motivo: string): Promise<Resultado>;
  corregirTemporada(u: UsuarioActivo, id: string, c: CorreccionTemporada): Promise<Resultado>;
  eliminarTemporada(u: UsuarioActivo, id: string): Promise<Resultado>;
}

const iso = (d: Date | string) => new Date(d).toISOString();

/** Las correcciones sobre Postgres, cada una en su transacción con su historial. */
export class CorreccionesPg implements Correcciones {
  constructor(private readonly pool: pg.Pool) {}

  /** Corre [f] en una transacción; un Resultado de error deshace todo. */
  private async tx<T>(f: (c: pg.PoolClient) => Promise<Resultado<T>>): Promise<Resultado<T>> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const r = await f(client);
      await client.query(r.ok ? "COMMIT" : "ROLLBACK");
      return r;
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  private historial(
    c: pg.PoolClient,
    u: UsuarioActivo,
    entidad: string,
    id: string,
    accion: "corregir" | "anular" | "eliminar",
    antes: unknown,
    despues: unknown,
    motivoTexto?: string | null,
  ) {
    return c.query(
      `INSERT INTO correcciones (organizacion_id, entidad, entidad_id, accion, antes, despues, motivo, usuario_uid)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [u.organizacionId, entidad, id, accion, JSON.stringify(antes), JSON.stringify(despues), motivoTexto ?? null, u.uid],
    );
  }

  private async entrega(c: pg.PoolClient, u: UsuarioActivo, id: string) {
    const { rows } = await c.query(
      `SELECT e.id, e.kg::float8 AS kg, e.estado, e.fecha, e.creado_por AS "creadoPor", e.finca_id AS "fincaId",
              e.anulada_en IS NOT NULL AS anulada, e.attestation_uid IS NOT NULL AS atestada, f.cultivo,
              (SELECT l.codigo FROM lote_entregas le JOIN lotes l ON l.id = le.lote_id WHERE le.entrega_id = e.id) AS "loteCodigo"
       FROM entregas e JOIN fincas f ON f.id = e.finca_id JOIN productores p ON p.id = f.productor_id
       WHERE e.id = $1 AND p.organizacion_id = $2 FOR UPDATE OF e`,
      [id, u.organizacionId],
    );
    return rows[0] as
      | { id: string; kg: number; estado: string; fecha: Date; creadoPor: string; fincaId: string; anulada: boolean; atestada: boolean; cultivo: string; loteCodigo: string | null }
      | undefined;
  }

  corregirEntrega(u: UsuarioActivo, id: string, cambios: CorreccionEntrega) {
    return this.tx<EntregaCorregida>(async (c) => {
      const e = await this.entrega(c, u, id);
      if (!e) return no(404, "No encontrada.");
      const bloqueo = sinPermiso(u, e.creadoPor) ?? entregaSellada(e);
      if (bloqueo) return no(sinPermiso(u, e.creadoPor) ? 403 : 409, bloqueo);
      const cul = cultivo(e.cultivo);
      if (cambios.estado && !estadoValido(e.cultivo, cambios.estado)) {
        return no(422, `"${cambios.estado}" no es un estado de ${cul?.nombre ?? e.cultivo}.`);
      }
      if (cambios.kg && cul && cambios.kg > cul.maxKgEntrega) {
        return no(422, `Más de ${cul.maxKgEntrega} kg en una entrega parece un error.`);
      }
      const d = diferencias(
        { kg: e.kg, estado: e.estado, fecha: iso(e.fecha) },
        { kg: cambios.kg, estado: cambios.estado, fecha: cambios.fecha ? iso(cambios.fecha) : undefined },
      );
      if (d.hay) {
        await c.query(
          `UPDATE entregas SET kg = coalesce($3, kg), estado = coalesce($4, estado), fecha = coalesce($5::timestamptz, fecha),
                  temporada_id = ${TEMPORADA_DE("$2", "coalesce($5::timestamptz, fecha)", "finca_id")}
           WHERE id = $1`,
          [id, u.organizacionId, cambios.kg ?? null, cambios.estado ?? null, cambios.fecha ?? null],
        );
        await this.historial(c, u, "entrega", id, "corregir", d.antes, d.despues, cambios.motivo);
      }
      const { rows } = await c.query(
        `SELECT id, kg::float8 AS kg, estado, fecha, temporada_id AS "temporadaId" FROM entregas WHERE id = $1`,
        [id],
      );
      return ok({ ...rows[0], fecha: iso(rows[0].fecha) });
    });
  }

  anularEntrega(u: UsuarioActivo, id: string, motivoTexto: string) {
    return this.tx(async (c) => {
      const e = await this.entrega(c, u, id);
      if (!e) return no(404, "No encontrada.");
      const permiso = sinPermiso(u, e.creadoPor);
      if (permiso) return no(403, permiso);
      const sellada = entregaSellada(e);
      if (sellada) return no(409, sellada);
      await c.query("UPDATE entregas SET anulada_en = now(), anulada_por = $2, motivo_anulacion = $3 WHERE id = $1", [id, u.uid, motivoTexto]);
      await c.query("DELETE FROM attestations_pendientes WHERE esquema = 'Entrega' AND entidad_id = $1", [id]);
      await this.historial(c, u, "entrega", id, "anular", { kg: e.kg, estado: e.estado, fecha: iso(e.fecha) }, {}, motivoTexto);
      return ok(null);
    });
  }

  corregirLote(u: UsuarioActivo, id: string, cambios: CorreccionLote) {
    return this.tx(async (c) => {
      const { rows } = await c.query(
        `SELECT l.id, l.codigo, l.cultivo, l.temporada_id AS "temporadaId", l.estado, l.kg::float8 AS kg, l.beneficio, l.proceso,
                l.attestation_uid IS NOT NULL AS atestado,
                (SELECT x.codigo FROM exportacion_lotes el JOIN exportaciones x ON x.id = el.exportacion_id WHERE el.lote_id = l.id) AS contenedor,
                (SELECT array_agg(le.entrega_id) FROM lote_entregas le WHERE le.lote_id = l.id) AS entregas
         FROM lotes l WHERE l.id = $1 AND l.organizacion_id = $2 FOR UPDATE`,
        [id, u.organizacionId],
      );
      const l = rows[0];
      if (!l) return no(404, "No encontrado.");
      if (u.rol !== "admin") return no(403, "Solo un administrador puede corregir lotes.");
      if (l.contenedor) return no(409, `El lote va en el contenedor ${l.contenedor}; para corregirlo, primero deshaz el contenedor.`);
      if (l.atestado) return no(409, "El lote ya está firmado en la blockchain; no se puede corregir.");
      const d = diferencias(
        { kg: l.kg, codigo: l.codigo, beneficio: l.beneficio, proceso: l.proceso },
        { kg: cambios.kg, codigo: cambios.codigo, beneficio: cambios.beneficio, proceso: cambios.proceso },
      );
      if (!d.hay) return ok(null);
      // Con el peso nuevo se recalculan los avisos (volumen, rendimiento, satélite).
      let avisos: Aviso[] | null = null;
      let kgEsperados: number | null = null;
      if (cambios.kg !== undefined) {
        const candidatas = (await new PgRepo(this.pool).entregasCandidatas(u.organizacionId, { ids: l.entregas }))
          .map((e) => (e.loteCodigo === l.codigo ? { ...e, loteCodigo: null } : e));
        const ev = evaluarLote(
          { codigo: l.codigo, cultivo: l.cultivo, temporadaId: l.temporadaId, estado: l.estado, kg: cambios.kg, entregas: l.entregas },
          candidatas,
        );
        avisos = ev.avisos;
        kgEsperados = ev.kgEsperados;
      }
      try {
        await c.query("SAVEPOINT codigo");
        await c.query(
          `UPDATE lotes SET kg = coalesce($2, kg), codigo = coalesce($3, codigo), beneficio = coalesce($4, beneficio),
                  proceso = CASE WHEN $5 THEN $6 ELSE proceso END,
                  avisos = coalesce($7::jsonb, avisos), kg_esperados = coalesce($8, kg_esperados)
           WHERE id = $1`,
          [id, cambios.kg ?? null, cambios.codigo ?? null, cambios.beneficio ?? null, cambios.proceso !== undefined,
           cambios.proceso ?? null, avisos ? JSON.stringify(avisos) : null, kgEsperados],
        );
      } catch (e) {
        if ((e as { constraint?: string }).constraint === "lotes_codigo_unico") {
          await c.query("ROLLBACK TO SAVEPOINT codigo");
          return no(409, `Ya existe un lote con el código ${cambios.codigo}.`);
        }
        throw e;
      }
      await this.historial(c, u, "lote", id, "corregir", d.antes, d.despues, cambios.motivo);
      return ok(null);
    });
  }

  corregirProductor(u: UsuarioActivo, id: string, cambios: CorreccionProductor) {
    return this.tx(async (c) => {
      const { rows } = await c.query(
        "SELECT nombre, cedula, comunidad, creado_por AS \"creadoPor\" FROM productores WHERE id = $1 AND organizacion_id = $2 FOR UPDATE",
        [id, u.organizacionId],
      );
      const p = rows[0];
      if (!p) return no(404, "No encontrado.");
      const permiso = sinPermiso(u, p.creadoPor);
      if (permiso) return no(403, permiso);
      const cedula = cambios.cedula === undefined ? undefined : cambios.cedula ? normalizarCedula(cambios.cedula) : null;
      const d = diferencias(p, { nombre: cambios.nombre, cedula, comunidad: cambios.comunidad === "" ? null : cambios.comunidad });
      if (!d.hay) return ok(null);
      await c.query(
        `UPDATE productores SET nombre = CASE WHEN $2 THEN $3 ELSE nombre END,
                cedula = CASE WHEN $4 THEN $5 ELSE cedula END, comunidad = CASE WHEN $6 THEN $7 ELSE comunidad END
         WHERE id = $1`,
        [id, "nombre" in d.despues, d.despues.nombre ?? null, "cedula" in d.despues, d.despues.cedula ?? null,
         "comunidad" in d.despues, d.despues.comunidad ?? null],
      );
      await this.historial(c, u, "productor", id, "corregir", d.antes, d.despues);
      return ok(null);
    });
  }

  corregirFinca(u: UsuarioActivo, id: string, cambios: CorreccionFinca) {
    return this.tx(async (c) => {
      const { rows } = await c.query(
        `SELECT f.nombre, f.area_ha::float8 AS "areaHa", f.creado_por AS "creadoPor", GeometryType(f.geom) AS tipo,
                f.version_actual AS version, fv.attestation_uid IS NOT NULL AS atestada
         FROM fincas f JOIN productores p ON p.id = f.productor_id
         JOIN fincas_versiones fv ON fv.finca_id = f.id AND fv.version = f.version_actual
         WHERE f.id = $1 AND p.organizacion_id = $2 FOR UPDATE OF f`,
        [id, u.organizacionId],
      );
      const f = rows[0];
      if (!f) return no(404, "No encontrada.");
      const permiso = sinPermiso(u, f.creadoPor);
      if (permiso) return no(403, permiso);
      if (cambios.areaHa !== undefined) {
        if (f.tipo !== "POINT") {
          return no(422, "El área de un polígono sale del lindero: para corregirla, marca un lindero nuevo en una visita de verificación.");
        }
        if (f.atestada) return no(409, "Este lindero ya está firmado en la blockchain: corrige el área con un lindero nuevo en una visita.");
      }
      const d = diferencias({ nombre: f.nombre, areaHa: f.areaHa }, { nombre: cambios.nombre, areaHa: cambios.areaHa });
      if (!d.hay) return ok(null);
      await c.query("UPDATE fincas SET nombre = coalesce($2, nombre), area_ha = coalesce($3, area_ha) WHERE id = $1", [
        id,
        cambios.nombre ?? null,
        cambios.areaHa ?? null,
      ]);
      if (cambios.areaHa !== undefined) {
        await c.query("UPDATE fincas_versiones SET area_ha = $3 WHERE finca_id = $1 AND version = $2", [id, f.version, cambios.areaHa]);
      }
      await this.historial(c, u, "finca", id, "corregir", d.antes, d.despues, cambios.motivo);
      return ok(null);
    });
  }

  eliminarFoto(u: UsuarioActivo, id: string) {
    return this.tx<{ storagePath: string | null }>(async (c) => {
      const { rows } = await c.query(
        `SELECT fo.entidad_tipo AS "entidadTipo", fo.entidad_id AS "entidadId", fo.tipo, fo.sha256,
                fo.storage_path AS "storagePath", fo.creado_por AS "creadoPor",
                CASE fo.entidad_tipo
                  WHEN 'finca' THEN EXISTS (SELECT 1 FROM fincas_versiones fv WHERE fv.finca_id = fo.entidad_id AND fv.attestation_uid IS NOT NULL)
                  WHEN 'verificacion' THEN EXISTS (SELECT 1 FROM verificaciones v WHERE v.id = fo.entidad_id AND v.attestation_uid IS NOT NULL)
                  ELSE false END AS sellada
         FROM fotos fo WHERE fo.id = $1 AND fo.organizacion_id = $2 FOR UPDATE`,
        [id, u.organizacionId],
      );
      const fo = rows[0];
      if (!fo) return no(404, "No encontrada.");
      const permiso = sinPermiso(u, fo.creadoPor);
      if (permiso) return no(403, permiso);
      if (fo.sellada) return no(409, "La foto ya forma parte de un registro firmado en la blockchain; no se puede quitar.");
      await c.query("DELETE FROM fotos WHERE id = $1", [id]);
      await this.historial(c, u, "foto", id, "eliminar", { entidadTipo: fo.entidadTipo, entidadId: fo.entidadId, tipo: fo.tipo, sha256: fo.sha256 }, {});
      return ok({ storagePath: fo.storagePath });
    });
  }

  private async visita(c: pg.PoolClient, u: UsuarioActivo, id: string) {
    const { rows } = await c.query(
      `SELECT v.nota, v.fecha, v.creado_por AS "creadoPor", v.lindero_cambio AS "linderoCambio",
              v.anulada_en IS NOT NULL AS anulada, v.attestation_uid IS NOT NULL AS atestada
       FROM verificaciones v JOIN fincas f ON f.id = v.finca_id JOIN productores p ON p.id = f.productor_id
       WHERE v.id = $1 AND p.organizacion_id = $2 FOR UPDATE OF v`,
      [id, u.organizacionId],
    );
    return rows[0] as
      | { nota: string | null; fecha: Date; creadoPor: string; linderoCambio: boolean; anulada: boolean; atestada: boolean }
      | undefined;
  }

  corregirVerificacion(u: UsuarioActivo, id: string, cambios: CorreccionVisita) {
    return this.tx(async (c) => {
      const v = await this.visita(c, u, id);
      if (!v) return no(404, "No encontrada.");
      const permiso = sinPermiso(u, v.creadoPor);
      if (permiso) return no(403, permiso);
      if (v.anulada) return no(409, "La visita ya está anulada.");
      if (cambios.fecha !== undefined) {
        const sellada = visitaSellada(v);
        if (sellada) return no(409, sellada);
      }
      const nota = cambios.nota === "" ? null : cambios.nota;
      const d = diferencias(
        { nota: v.nota, fecha: iso(v.fecha) },
        { nota, fecha: cambios.fecha ? iso(cambios.fecha) : undefined },
      );
      if (!d.hay) return ok(null);
      await c.query(
        `UPDATE verificaciones SET nota = CASE WHEN $3 THEN $4 ELSE nota END, fecha = coalesce($5::timestamptz, fecha),
                temporada_id = ${TEMPORADA_DE("$2", "coalesce($5::timestamptz, fecha)", "finca_id")}
         WHERE id = $1`,
        [id, u.organizacionId, "nota" in d.despues, nota ?? null, cambios.fecha ?? null],
      );
      await this.historial(c, u, "verificacion", id, "corregir", d.antes, d.despues, cambios.motivo);
      return ok(null);
    });
  }

  anularVerificacion(u: UsuarioActivo, id: string, motivoTexto: string) {
    return this.tx(async (c) => {
      const v = await this.visita(c, u, id);
      if (!v) return no(404, "No encontrada.");
      const permiso = sinPermiso(u, v.creadoPor);
      if (permiso) return no(403, permiso);
      const sellada = visitaSellada(v);
      if (sellada) return no(409, sellada);
      await c.query("UPDATE verificaciones SET anulada_en = now(), anulada_por = $2, motivo_anulacion = $3 WHERE id = $1", [id, u.uid, motivoTexto]);
      await c.query("DELETE FROM attestations_pendientes WHERE esquema = 'Verificacion' AND entidad_id = $1", [id]);
      await this.historial(c, u, "verificacion", id, "anular", { fecha: iso(v.fecha), nota: v.nota }, {}, motivoTexto);
      return ok(null);
    });
  }

  /**
   * Reasigna la temporada de las entregas (fuera de lotes) y visitas (sin
   * firmar) de la organización según las temporadas que quedan. Misma regla
   * que TEMPORADA_DE: la del cultivo gana sobre la general.
   */
  private async reasignarTemporadas(c: pg.PoolClient, org: string) {
    await c.query(
      `UPDATE entregas x SET temporada_id = ${TEMPORADA_DE("$1", "x.fecha", "x.finca_id")}
       FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE x.finca_id = f.id AND p.organizacion_id = $1
         AND NOT EXISTS (SELECT 1 FROM lote_entregas le WHERE le.entrega_id = x.id)`,
      [org],
    );
    await c.query(
      `UPDATE verificaciones x SET temporada_id = ${TEMPORADA_DE("$1", "x.fecha", "x.finca_id")}
       FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE x.finca_id = f.id AND p.organizacion_id = $1 AND x.attestation_uid IS NULL`,
      [org],
    );
  }

  private async temporada(c: pg.PoolClient, u: UsuarioActivo, id: string) {
    const { rows } = await c.query(
      `SELECT t.nombre, to_char(t.inicio, 'YYYY-MM-DD') AS inicio, to_char(t.fin, 'YYYY-MM-DD') AS fin,
              EXISTS (SELECT 1 FROM lotes l WHERE l.temporada_id = t.id) AS "conLotes"
       FROM temporadas t WHERE t.id = $1 AND t.organizacion_id = $2 FOR UPDATE`,
      [id, u.organizacionId],
    );
    return rows[0] as { nombre: string; inicio: string; fin: string; conLotes: boolean } | undefined;
  }

  corregirTemporada(u: UsuarioActivo, id: string, cambios: CorreccionTemporada) {
    return this.tx(async (c) => {
      const t = await this.temporada(c, u, id);
      if (!t) return no(404, "No encontrada.");
      if (u.rol !== "admin") return no(403, "Solo un administrador puede corregir temporadas.");
      const fechas = cambios.inicio !== undefined || cambios.fin !== undefined;
      if (fechas && t.conLotes) return no(409, "La temporada ya tiene lotes: sus fechas no se pueden cambiar.");
      const inicio = cambios.inicio ?? t.inicio;
      const fin = cambios.fin ?? t.fin;
      if (inicio >= fin) return no(422, "La temporada debe terminar después de empezar.");
      const d = diferencias(t, { nombre: cambios.nombre, inicio: cambios.inicio, fin: cambios.fin });
      if (!d.hay) return ok(null);
      try {
        await c.query("SAVEPOINT fechas");
        await c.query("UPDATE temporadas SET nombre = coalesce($2, nombre), inicio = $3, fin = $4 WHERE id = $1", [
          id,
          cambios.nombre ?? null,
          inicio,
          fin,
        ]);
      } catch (e) {
        if ((e as { constraint?: string }).constraint === "temporadas_sin_traslape") {
          await c.query("ROLLBACK TO SAVEPOINT fechas");
          return no(409, "Esas fechas se cruzan con otra temporada.");
        }
        throw e;
      }
      if (fechas) await this.reasignarTemporadas(c, u.organizacionId);
      await this.historial(c, u, "temporada", id, "corregir", d.antes, d.despues, cambios.motivo);
      return ok(null);
    });
  }

  eliminarTemporada(u: UsuarioActivo, id: string) {
    return this.tx(async (c) => {
      const t = await this.temporada(c, u, id);
      if (!t) return no(404, "No encontrada.");
      if (u.rol !== "admin") return no(403, "Solo un administrador puede eliminar temporadas.");
      if (t.conLotes) return no(409, "La temporada ya tiene lotes: no se puede eliminar.");
      for (const tabla of ["entregas", "verificaciones", "chequeos_deforestacion"]) {
        await c.query(`UPDATE ${tabla} SET temporada_id = NULL WHERE temporada_id = $1`, [id]);
      }
      await c.query("DELETE FROM temporadas WHERE id = $1", [id]);
      await this.reasignarTemporadas(c, u.organizacionId);
      await this.historial(c, u, "temporada", id, "eliminar", t, {});
      return ok(null);
    });
  }
}
