import type pg from "pg";
import type { Rol, UsuarioActivo } from "./auth.ts";
import type { LoteSync, TemporadaNueva } from "./sync.ts";

export class AccesoDenegado extends Error {}

/** La versión del lindero que llegó no sigue a la vigente (otro técnico se adelantó). */
export class VersionDesfasada extends Error {}

export interface Invitacion {
  email: string;
  organizacionId: string;
  rol: Rol;
  invitadoPor: string;
  usuarioUid: string | null;
  creadoEn: string;
  aceptadaEn: string | null;
}

export interface ResultadoEliminarFinca {
  estado: "eliminada" | "no_encontrada" | "atestada";
  archivos: string[];
}

export interface Temporada {
  id: string;
  nombre: string;
  inicio: string;
  fin: string;
}

export type EstadoDeforestacion = "pendiente" | "verde" | "amarillo" | "rojo";

export interface DatosOrganizacion {
  /** De la más reciente a la más antigua; las fechas son días en Nicaragua. */
  temporadas: Temporada[];
  productores: {
    id: string;
    nombre: string;
    cedula: string | null;
    comunidad: string | null;
    consentimientoFirmado: boolean;
  }[];
  fincas: {
    id: string;
    productorId: string;
    nombre: string;
    coordenadas: [number, number][];
    areaHa: number;
    /** Área calculada por PostGIS sobre el elipsoide: la que va al paquete EUDR. */
    areaOficialHa: number;
    geoHash: string;
    version: number;
    deforestacion: EstadoDeforestacion;
    ultimoChequeo: string | null;
    attestationUid: string | null;
  }[];
  verificaciones: {
    id: string;
    fincaId: string;
    temporadaId: string | null;
    fecha: string;
    linderoCambio: boolean;
    versionFinca: number;
    nota: string | null;
  }[];
  entregas: {
    id: string;
    fincaId: string;
    temporadaId: string | null;
    kg: number;
    estado: string;
    fecha: string;
    attestationUid: string | null;
  }[];
}

/** Finca a revisar por satélite: su lindero vigente como GeoJSON. */
export interface FincaPorRevisar {
  fincaId: string;
  version: number;
  temporadaId: string | null;
  /** Polígono; si la finca es un punto, un círculo de su área declarada. */
  geometria: { type: "Polygon" | "MultiPolygon"; coordinates: unknown };
}

export interface Chequeo {
  fincaId: string;
  version: number;
  temporadaId: string | null;
  fuente: string;
  alertas: number;
  areaAfectadaHa: number;
  resultado: Exclude<EstadoDeforestacion, "pendiente">;
  detalle: unknown;
}

export interface Repo {
  /** Guarda (idempotente) lo que llega de la app y encola las attestations. */
  guardarSync(usuario: UsuarioActivo, datos: LoteSync): Promise<void>;

  buscarInvitacion(email: string): Promise<Invitacion | null>;
  /** Marca la invitación como aceptada por esa cuenta de Firebase. */
  aceptarInvitacion(email: string, uid: string): Promise<void>;
  /** `false` si el correo ya tiene una invitación (en cualquier organización). */
  crearInvitacion(inv: Pick<Invitacion, "email" | "organizacionId" | "rol" | "invitadoPor">): Promise<boolean>;
  listarInvitaciones(organizacionId: string): Promise<Invitacion[]>;
  /** Devuelve la invitación borrada, o `null` si no existía en esa organización. */
  eliminarInvitacion(organizacionId: string, email: string): Promise<Invitacion | null>;

  /**
   * Borra una finca de la organización si ni ella ni sus entregas se
   * atestaron, con sus versiones, visitas, chequeos, entregas, fotos y
   * attestations pendientes. Lo atestado no se borra: hay que revocar su
   * attestation (semana 4). Devuelve las rutas en Storage de las fotos.
   */
  eliminarFinca(organizacionId: string, fincaId: string): Promise<ResultadoEliminarFinca>;

  /** Todo lo de la organización, para que cada celular vea lo del equipo. */
  datosOrganizacion(organizacionId: string): Promise<DatosOrganizacion>;

  /** Foto de la organización, o `null` si no existe o es de otra. */
  buscarFoto(organizacionId: string, fotoId: string): Promise<{ sha256: string; storagePath: string | null } | null>;
  marcarFotoSubida(fotoId: string, storagePath: string): Promise<void>;

  listarTemporadas(organizacionId: string): Promise<Temporada[]>;
  /**
   * Crea la temporada y le asigna las entregas y visitas que quedaron sin
   * temporada en esas fechas. `null` si se traslapa con otra.
   */
  crearTemporada(organizacionId: string, t: TemporadaNueva & { id: string }, uid: string): Promise<Temporada | null>;

  /** Fincas con temporada vigente sin chequeo de su lindero actual en esa temporada. */
  fincasPorRevisar(limite: number): Promise<FincaPorRevisar[]>;
  /** La finca de la organización para revisarla ahora, o `null` si no es suya. */
  fincaParaRevisar(organizacionId: string, fincaId: string): Promise<FincaPorRevisar | null>;
  guardarChequeo(c: Chequeo): Promise<void>;
}

const COLUMNAS_INVITACION = `email, organizacion_id AS "organizacionId", rol, invitado_por AS "invitadoPor",
  usuario_uid AS "usuarioUid", creado_en AS "creadoEn", aceptada_en AS "aceptadaEn"`;

/**
 * Temporada de la organización que contiene un instante. Las fechas de
 * temporada son días de calendario en Nicaragua, no en UTC.
 */
const TEMPORADA_DE = (org: string, fecha: string) =>
  `(SELECT id FROM temporadas WHERE organizacion_id = ${org}
     AND (${fecha}::timestamptz AT TIME ZONE 'America/Managua')::date BETWEEN inicio AND fin)`;

/** Geometría para el satélite: los puntos se vuelven un círculo de su área. */
const GEOMETRIA_SATELITE = `ST_AsGeoJSON(CASE WHEN GeometryType(f.geom) = 'POINT'
    THEN ST_Buffer(f.geom::geography, sqrt(f.area_ha * 10000 / pi()))::geometry
    ELSE f.geom END, 7)::json`;

export class PgRepo implements Repo {
  constructor(private readonly pool: pg.Pool) {}

  async guardarSync(
    usuario: UsuarioActivo,
    { productores, fincas, versionesFinca, verificaciones, entregas, fotos }: LoteSync,
  ): Promise<void> {
    const org = usuario.organizacionId;
    const client = await this.pool.connect();
    const fincaDeLaOrganizacion = async (fincaId: string) => {
      const r = await client.query(
        `SELECT f.version_actual FROM fincas f JOIN productores p ON p.id = f.productor_id
         WHERE f.id = $1 AND p.organizacion_id = $2`,
        [fincaId, org],
      );
      if (r.rowCount === 0) throw new AccesoDenegado(`Finca ${fincaId} no pertenece a la organización`);
      return r.rows[0].version_actual as number;
    };

    try {
      await client.query("BEGIN");
      for (const p of productores) {
        await client.query(
          `INSERT INTO productores (id, organizacion_id, nombre, cedula, comunidad, consentimiento_firmado, creado_por)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, cedula = EXCLUDED.cedula,
             comunidad = EXCLUDED.comunidad
           WHERE productores.organizacion_id = EXCLUDED.organizacion_id`,
          [p.id, org, p.nombre, p.cedula ?? null, p.comunidad ?? null, p.consentimientoFirmado, usuario.uid],
        );
      }

      for (const f of fincas) {
        const propio = await client.query("SELECT 1 FROM productores WHERE id = $1 AND organizacion_id = $2", [
          f.productorId,
          org,
        ]);
        if (propio.rowCount === 0) throw new AccesoDenegado(`Productor ${f.productorId} no pertenece a la organización`);

        // Una finca ya registrada no se modifica; un lindero nuevo llega como versión.
        const nueva = await client.query(
          `INSERT INTO fincas (id, productor_id, nombre, geom, area_ha, geo_hash, creado_por)
           VALUES ($1, $2, $3, ST_SetSRID(ST_GeomFromGeoJSON($4), 4326), $5, $6, $7)
           ON CONFLICT (id) DO NOTHING`,
          [f.id, f.productorId, f.nombre, JSON.stringify(aGeometria(f.coordenadas)), f.areaHa, f.geoHash, usuario.uid],
        );
        if (nueva.rowCount === 1) {
          await client.query(
            `INSERT INTO fincas_versiones (finca_id, version, geom, area_ha, geo_hash, creado_por)
             SELECT id, 1, geom, area_ha, geo_hash, creado_por FROM fincas WHERE id = $1`,
            [f.id],
          );
        }
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id, version) VALUES ('Finca', $1, 1)
           ON CONFLICT DO NOTHING`,
          [f.id],
        );
      }

      for (const v of versionesFinca) {
        const actual = await fincaDeLaOrganizacion(v.fincaId);
        if (v.version <= actual) {
          // Ya recibida (reintento de sincronización): solo se acepta si es la misma.
          const igual = await client.query(
            "SELECT 1 FROM fincas_versiones WHERE finca_id = $1 AND version = $2 AND geo_hash = $3",
            [v.fincaId, v.version, v.geoHash],
          );
          if (igual.rowCount === 1) continue;
          throw new VersionDesfasada(
            `La finca ya tiene una versión ${v.version} distinta; sincroniza para ver el lindero vigente.`,
          );
        }
        if (v.version !== actual + 1) {
          throw new VersionDesfasada(`Falta la versión ${actual + 1} del lindero antes de la ${v.version}.`);
        }
        const geom = JSON.stringify(aGeometria(v.coordenadas));
        await client.query(
          `INSERT INTO fincas_versiones (finca_id, version, geom, area_ha, geo_hash, creado_por)
           VALUES ($1, $2, ST_SetSRID(ST_GeomFromGeoJSON($3), 4326), $4, $5, $6)`,
          [v.fincaId, v.version, geom, v.areaHa, v.geoHash, usuario.uid],
        );
        await client.query(
          `UPDATE fincas SET geom = ST_SetSRID(ST_GeomFromGeoJSON($2), 4326), area_ha = $3, geo_hash = $4,
             version_actual = $5, deforestacion = 'pendiente', attestation_uid = NULL
           WHERE id = $1`,
          [v.fincaId, geom, v.areaHa, v.geoHash, v.version],
        );
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id, version) VALUES ('Finca', $1, $2)
           ON CONFLICT DO NOTHING`,
          [v.fincaId, v.version],
        );
      }

      for (const v of verificaciones) {
        await fincaDeLaOrganizacion(v.fincaId);
        await client.query(
          `INSERT INTO verificaciones (id, finca_id, temporada_id, fecha, lindero_cambio, version_finca, nota, creado_por)
           VALUES ($1, $2, ${TEMPORADA_DE("$3", "$4")}, $4, $5, $6, $7, $8)
           ON CONFLICT (id) DO NOTHING`,
          [v.id, v.fincaId, org, v.fecha, v.linderoCambio, v.versionFinca, v.nota ?? null, usuario.uid],
        );
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Verificacion', $1)
           ON CONFLICT DO NOTHING`,
          [v.id],
        );
      }

      for (const e of entregas) {
        await fincaDeLaOrganizacion(e.fincaId);
        // Como las fincas, una entrega no se modifica después de recibida.
        await client.query(
          `INSERT INTO entregas (id, finca_id, temporada_id, kg, estado, fecha, creado_por)
           VALUES ($1, $2, ${TEMPORADA_DE("$3", "$6")}, $4, $5, $6, $7)
           ON CONFLICT (id) DO NOTHING`,
          [e.id, e.fincaId, org, e.kg, e.estado, e.fecha, usuario.uid],
        );
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Entrega', $1)
           ON CONFLICT DO NOTHING`,
          [e.id],
        );
      }

      for (const foto of fotos) {
        const consulta = {
          productor: "SELECT 1 FROM productores WHERE id = $1 AND organizacion_id = $2",
          finca: `SELECT 1 FROM fincas f JOIN productores p ON p.id = f.productor_id
                  WHERE f.id = $1 AND p.organizacion_id = $2`,
          verificacion: `SELECT 1 FROM verificaciones v JOIN fincas f ON f.id = v.finca_id
                         JOIN productores p ON p.id = f.productor_id
                         WHERE v.id = $1 AND p.organizacion_id = $2`,
        }[foto.entidadTipo];
        const propia = await client.query(consulta, [foto.entidadId, org]);
        if (propia.rowCount === 0) {
          throw new AccesoDenegado(`${foto.entidadTipo} ${foto.entidadId} no pertenece a la organización`);
        }
        await client.query(
          `INSERT INTO fotos (id, organizacion_id, entidad_tipo, entidad_id, tipo, sha256, creado_por)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           ON CONFLICT (id) DO NOTHING`,
          [foto.id, org, foto.entidadTipo, foto.entidadId, foto.tipo, foto.sha256, usuario.uid],
        );
      }
      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async buscarInvitacion(email: string): Promise<Invitacion | null> {
    const { rows } = await this.pool.query<Invitacion>(
      `SELECT ${COLUMNAS_INVITACION} FROM invitaciones WHERE email = $1`,
      [email.toLowerCase()],
    );
    return rows[0] ?? null;
  }

  async aceptarInvitacion(email: string, uid: string): Promise<void> {
    await this.pool.query(
      `UPDATE invitaciones SET usuario_uid = $2, aceptada_en = COALESCE(aceptada_en, now())
       WHERE email = $1`,
      [email.toLowerCase(), uid],
    );
  }

  async crearInvitacion(inv: Pick<Invitacion, "email" | "organizacionId" | "rol" | "invitadoPor">): Promise<boolean> {
    const r = await this.pool.query(
      `INSERT INTO invitaciones (email, organizacion_id, rol, invitado_por) VALUES ($1, $2, $3, $4)
       ON CONFLICT (email) DO NOTHING`,
      [inv.email.toLowerCase(), inv.organizacionId, inv.rol, inv.invitadoPor],
    );
    return r.rowCount === 1;
  }

  async listarInvitaciones(organizacionId: string): Promise<Invitacion[]> {
    const { rows } = await this.pool.query<Invitacion>(
      `SELECT ${COLUMNAS_INVITACION} FROM invitaciones WHERE organizacion_id = $1 ORDER BY rol, email`,
      [organizacionId],
    );
    return rows;
  }

  async eliminarInvitacion(organizacionId: string, email: string): Promise<Invitacion | null> {
    const { rows } = await this.pool.query<Invitacion>(
      `DELETE FROM invitaciones WHERE organizacion_id = $1 AND email = $2 RETURNING ${COLUMNAS_INVITACION}`,
      [organizacionId, email.toLowerCase()],
    );
    return rows[0] ?? null;
  }

  async eliminarFinca(organizacionId: string, fincaId: string): Promise<ResultadoEliminarFinca> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const { rows } = await client.query<{ atestada: boolean }>(
        `SELECT EXISTS (SELECT 1 FROM fincas_versiones fv WHERE fv.finca_id = f.id AND fv.attestation_uid IS NOT NULL)
                OR f.attestation_uid IS NOT NULL
                OR EXISTS (SELECT 1 FROM entregas e WHERE e.finca_id = f.id AND e.attestation_uid IS NOT NULL)
                OR EXISTS (SELECT 1 FROM verificaciones v WHERE v.finca_id = f.id AND v.attestation_uid IS NOT NULL)
                AS atestada
         FROM fincas f JOIN productores p ON p.id = f.productor_id
         WHERE f.id = $1 AND p.organizacion_id = $2 FOR UPDATE OF f`,
        [fincaId, organizacionId],
      );
      if (rows.length === 0 || rows[0].atestada) {
        await client.query("ROLLBACK");
        return { estado: rows.length === 0 ? "no_encontrada" : "atestada", archivos: [] };
      }
      await client.query(
        `DELETE FROM attestations_pendientes
         WHERE (esquema = 'Finca' AND entidad_id = $1)
            OR (esquema = 'Entrega' AND entidad_id IN (SELECT id FROM entregas WHERE finca_id = $1))
            OR (esquema = 'Verificacion' AND entidad_id IN (SELECT id FROM verificaciones WHERE finca_id = $1))`,
        [fincaId],
      );
      const fotos = await client.query<{ storage_path: string | null }>(
        `DELETE FROM fotos
         WHERE (entidad_tipo = 'finca' AND entidad_id = $1)
            OR (entidad_tipo = 'verificacion' AND entidad_id IN (SELECT id FROM verificaciones WHERE finca_id = $1))
         RETURNING storage_path`,
        [fincaId],
      );
      for (const tabla of ["entregas", "verificaciones", "chequeos_deforestacion", "fincas_versiones"]) {
        await client.query(`DELETE FROM ${tabla} WHERE finca_id = $1`, [fincaId]);
      }
      await client.query("DELETE FROM fincas WHERE id = $1", [fincaId]);
      await client.query("COMMIT");
      return { estado: "eliminada", archivos: fotos.rows.flatMap((f) => (f.storage_path ? [f.storage_path] : [])) };
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async datosOrganizacion(organizacionId: string): Promise<DatosOrganizacion> {
    const temporadas = await this.listarTemporadas(organizacionId);
    const productores = await this.pool.query(
      `SELECT id, nombre, cedula, comunidad, consentimiento_firmado AS "consentimientoFirmado"
       FROM productores WHERE organizacion_id = $1 ORDER BY nombre`,
      [organizacionId],
    );
    // 15 decimales: las mismas coordenadas que mandó la app, para que el
    // geoHash se pueda recalcular en cualquier celular.
    const fincas = await this.pool.query(
      `SELECT f.id, f.productor_id AS "productorId", f.nombre, ST_AsGeoJSON(f.geom, 15)::json AS geom,
              f.area_ha::float8 AS "areaHa", f.area_oficial_ha::float8 AS "areaOficialHa",
              f.geo_hash AS "geoHash", f.version_actual AS version, f.deforestacion,
              (SELECT max(c.fecha) FROM chequeos_deforestacion c WHERE c.finca_id = f.id) AS "ultimoChequeo",
              f.attestation_uid AS "attestationUid"
       FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE p.organizacion_id = $1 ORDER BY f.creado_en`,
      [organizacionId],
    );
    const verificaciones = await this.pool.query(
      `SELECT v.id, v.finca_id AS "fincaId", v.temporada_id AS "temporadaId", v.fecha,
              v.lindero_cambio AS "linderoCambio", v.version_finca AS "versionFinca", v.nota
       FROM verificaciones v JOIN fincas f ON f.id = v.finca_id JOIN productores p ON p.id = f.productor_id
       WHERE p.organizacion_id = $1 ORDER BY v.fecha`,
      [organizacionId],
    );
    const entregas = await this.pool.query(
      `SELECT e.id, e.finca_id AS "fincaId", e.temporada_id AS "temporadaId", e.kg::float8 AS kg, e.estado,
              e.fecha, e.attestation_uid AS "attestationUid"
       FROM entregas e JOIN fincas f ON f.id = e.finca_id JOIN productores p ON p.id = f.productor_id
       WHERE p.organizacion_id = $1 ORDER BY e.fecha`,
      [organizacionId],
    );
    const iso = (d: Date | null) => (d ? new Date(d).toISOString() : null);
    return {
      temporadas,
      productores: productores.rows,
      fincas: fincas.rows.map(({ geom, ultimoChequeo, ...f }) => ({
        ...f,
        coordenadas: desdeGeometria(geom),
        ultimoChequeo: iso(ultimoChequeo),
      })),
      verificaciones: verificaciones.rows.map((v) => ({ ...v, fecha: iso(v.fecha)! })),
      entregas: entregas.rows.map((e) => ({ ...e, fecha: iso(e.fecha)! })),
    };
  }

  async buscarFoto(organizacionId: string, fotoId: string) {
    const { rows } = await this.pool.query<{ sha256: string; storagePath: string | null }>(
      `SELECT sha256, storage_path AS "storagePath" FROM fotos WHERE id = $1 AND organizacion_id = $2`,
      [fotoId, organizacionId],
    );
    return rows[0] ?? null;
  }

  async marcarFotoSubida(fotoId: string, storagePath: string): Promise<void> {
    await this.pool.query("UPDATE fotos SET storage_path = $2 WHERE id = $1", [fotoId, storagePath]);
  }

  async listarTemporadas(organizacionId: string): Promise<Temporada[]> {
    const { rows } = await this.pool.query<Temporada>(
      `SELECT id, nombre, to_char(inicio, 'YYYY-MM-DD') AS inicio, to_char(fin, 'YYYY-MM-DD') AS fin
       FROM temporadas WHERE organizacion_id = $1 ORDER BY inicio DESC`,
      [organizacionId],
    );
    return rows;
  }

  async crearTemporada(organizacionId: string, t: TemporadaNueva & { id: string }, uid: string) {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `INSERT INTO temporadas (id, organizacion_id, nombre, inicio, fin, creado_por) VALUES ($1, $2, $3, $4, $5, $6)`,
        [t.id, organizacionId, t.nombre, t.inicio, t.fin, uid],
      );
      // Lo que llegó antes de crear la temporada queda asignado ahora.
      for (const tabla of ["entregas", "verificaciones"]) {
        await client.query(
          `UPDATE ${tabla} x SET temporada_id = $1
           FROM fincas f JOIN productores p ON p.id = f.productor_id
           WHERE x.finca_id = f.id AND p.organizacion_id = $2 AND x.temporada_id IS NULL
             AND (x.fecha AT TIME ZONE 'America/Managua')::date BETWEEN $3 AND $4`,
          [t.id, organizacionId, t.inicio, t.fin],
        );
      }
      await client.query("COMMIT");
      return { id: t.id, nombre: t.nombre, inicio: t.inicio, fin: t.fin };
    } catch (e) {
      await client.query("ROLLBACK");
      if ((e as { constraint?: string }).constraint === "temporadas_sin_traslape") return null;
      throw e;
    } finally {
      client.release();
    }
  }

  async fincasPorRevisar(limite: number): Promise<FincaPorRevisar[]> {
    const { rows } = await this.pool.query(
      `SELECT f.id AS "fincaId", f.version_actual AS version, t.id AS "temporadaId", ${GEOMETRIA_SATELITE} AS geometria
       FROM fincas f
       JOIN productores p ON p.id = f.productor_id
       JOIN temporadas t ON t.organizacion_id = p.organizacion_id
         AND (now() AT TIME ZONE 'America/Managua')::date BETWEEN t.inicio AND t.fin
       WHERE NOT EXISTS (
         SELECT 1 FROM chequeos_deforestacion c
         WHERE c.finca_id = f.id AND c.temporada_id = t.id AND c.version_finca = f.version_actual)
       ORDER BY f.creado_en
       LIMIT $1`,
      [limite],
    );
    return rows;
  }

  async fincaParaRevisar(organizacionId: string, fincaId: string): Promise<FincaPorRevisar | null> {
    const { rows } = await this.pool.query(
      `SELECT f.id AS "fincaId", f.version_actual AS version,
              (SELECT t.id FROM temporadas t WHERE t.organizacion_id = p.organizacion_id
                 AND (now() AT TIME ZONE 'America/Managua')::date BETWEEN t.inicio AND t.fin) AS "temporadaId",
              ${GEOMETRIA_SATELITE} AS geometria
       FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE f.id = $1 AND p.organizacion_id = $2`,
      [fincaId, organizacionId],
    );
    return rows[0] ?? null;
  }

  async guardarChequeo(c: Chequeo): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      // Un chequeo nuevo de la misma temporada y versión reemplaza al anterior.
      await client.query(
        `INSERT INTO chequeos_deforestacion
           (finca_id, temporada_id, version_finca, fuente, alertas, area_afectada_ha, resultado, detalle)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (finca_id, temporada_id, version_finca) DO UPDATE SET
           fecha = now(), fuente = EXCLUDED.fuente, alertas = EXCLUDED.alertas,
           area_afectada_ha = EXCLUDED.area_afectada_ha, resultado = EXCLUDED.resultado, detalle = EXCLUDED.detalle`,
        [c.fincaId, c.temporadaId, c.version, c.fuente, c.alertas, c.areaAfectadaHa, c.resultado, JSON.stringify(c.detalle)],
      );
      // Solo si el chequeo es del lindero vigente cambia el estado de la finca.
      await client.query("UPDATE fincas SET deforestacion = $2 WHERE id = $1 AND version_actual = $3", [
        c.fincaId,
        c.resultado,
        c.version,
      ]);
      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }
}

/** Un punto si hay una coordenada; si no, un polígono con el anillo cerrado. */
export function aGeometria(coords: [number, number][]) {
  if (coords.length === 1) return { type: "Point", coordinates: coords[0] };
  return { type: "Polygon", coordinates: [[...coords, coords[0]]] };
}

/** Lo inverso de `aGeometria`: el anillo abierto, como lo guarda la app. */
export function desdeGeometria(g: { type: string; coordinates: unknown }): [number, number][] {
  if (g.type === "Point") return [g.coordinates as [number, number]];
  return (g.coordinates as [number, number][][])[0].slice(0, -1);
}
