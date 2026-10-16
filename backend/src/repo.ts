import type pg from "pg";
import type { Rol, UsuarioActivo } from "./auth.ts";
import type { LoteSync } from "./sync.ts";

export class AccesoDenegado extends Error {}

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

export interface DatosOrganizacion {
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
    deforestacion: string;
    attestationUid: string | null;
  }[];
  entregas: {
    id: string;
    fincaId: string;
    kg: number;
    estado: string;
    fecha: string;
    attestationUid: string | null;
  }[];
}

export interface Repo {
  /** Guarda (idempotente) lo que llega de la app y encola las attestations. */
  guardarSync(usuario: UsuarioActivo, datos: LoteSync): Promise<void>;

  buscarInvitacion(email: string): Promise<Invitacion | null>;
  /** Marca la invitación como aceptada por esa cuenta de Firebase. */
  aceptarInvitacion(email: string, uid: string): Promise<void>;
  /** `false` si el correo ya tiene una invitación (en cualquier organización). */
  crearInvitacion(inv: Pick<Invitacion, "email" | "organizacionId" | "rol" | "invitadoPor">): Promise<boolean>;
  /**
   * Borra una finca de la organización si ni ella ni sus entregas se
   * atestaron, con sus entregas, fotos y attestations pendientes. Lo
   * atestado no se borra: hay que revocar su attestation (semana 4).
   * Devuelve las rutas en Storage de las fotos borradas.
   */
  eliminarFinca(organizacionId: string, fincaId: string): Promise<ResultadoEliminarFinca>;

  /** Todo lo de la organización, para que cada celular vea lo del equipo. */
  datosOrganizacion(organizacionId: string): Promise<DatosOrganizacion>;

  /** Foto de la organización, o `null` si no existe o es de otra. */
  buscarFoto(organizacionId: string, fotoId: string): Promise<{ sha256: string; storagePath: string | null } | null>;
  marcarFotoSubida(fotoId: string, storagePath: string): Promise<void>;
  listarInvitaciones(organizacionId: string): Promise<Invitacion[]>;
  /** Devuelve la invitación borrada, o `null` si no existía en esa organización. */
  eliminarInvitacion(organizacionId: string, email: string): Promise<Invitacion | null>;
}

const COLUMNAS_INVITACION = `email, organizacion_id AS "organizacionId", rol, invitado_por AS "invitadoPor",
  usuario_uid AS "usuarioUid", creado_en AS "creadoEn", aceptada_en AS "aceptadaEn"`;

export class PgRepo implements Repo {
  constructor(private readonly pool: pg.Pool) {}

  async guardarSync(usuario: UsuarioActivo, { productores, fincas, entregas, fotos }: LoteSync): Promise<void> {
    const org = usuario.organizacionId;
    const client = await this.pool.connect();
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
        const propio = await client.query(
          "SELECT 1 FROM productores WHERE id = $1 AND organizacion_id = $2",
          [f.productorId, org],
        );
        if (propio.rowCount === 0) throw new AccesoDenegado(`Productor ${f.productorId} no pertenece a la organización`);

        // Una finca ya registrada no se modifica: su geoHash pudo ya atestarse.
        await client.query(
          `INSERT INTO fincas (id, productor_id, nombre, geom, area_ha, geo_hash, creado_por)
           VALUES ($1, $2, $3, ST_SetSRID(ST_GeomFromGeoJSON($4), 4326), $5, $6, $7)
           ON CONFLICT (id) DO NOTHING`,
          [f.id, f.productorId, f.nombre, JSON.stringify(aGeometria(f.coordenadas)), f.areaHa, f.geoHash, usuario.uid],
        );
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Finca', $1)
           ON CONFLICT DO NOTHING`,
          [f.id],
        );
      }
      for (const e of entregas) {
        const propia = await client.query(
          `SELECT 1 FROM fincas f JOIN productores p ON p.id = f.productor_id
           WHERE f.id = $1 AND p.organizacion_id = $2`,
          [e.fincaId, org],
        );
        if (propia.rowCount === 0) throw new AccesoDenegado(`Finca ${e.fincaId} no pertenece a la organización`);

        // Como las fincas, una entrega no se modifica después de recibida.
        await client.query(
          `INSERT INTO entregas (id, finca_id, kg, estado, fecha, creado_por)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO NOTHING`,
          [e.id, e.fincaId, e.kg, e.estado, e.fecha, usuario.uid],
        );
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Entrega', $1)
           ON CONFLICT DO NOTHING`,
          [e.id],
        );
      }
      for (const foto of fotos) {
        const propia = await client.query(
          foto.entidadTipo === "productor"
            ? "SELECT 1 FROM productores WHERE id = $1 AND organizacion_id = $2"
            : `SELECT 1 FROM fincas f JOIN productores p ON p.id = f.productor_id
               WHERE f.id = $1 AND p.organizacion_id = $2`,
          [foto.entidadId, org],
        );
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

  async eliminarFinca(organizacionId: string, fincaId: string): Promise<ResultadoEliminarFinca> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const { rows } = await client.query<{ atestada: boolean }>(
        `SELECT f.attestation_uid IS NOT NULL
                OR EXISTS (SELECT 1 FROM entregas e WHERE e.finca_id = f.id AND e.attestation_uid IS NOT NULL) AS atestada
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
            OR (esquema = 'Entrega' AND entidad_id IN (SELECT id FROM entregas WHERE finca_id = $1))`,
        [fincaId],
      );
      await client.query("DELETE FROM entregas WHERE finca_id = $1", [fincaId]);
      const fotos = await client.query<{ storage_path: string | null }>(
        "DELETE FROM fotos WHERE entidad_tipo = 'finca' AND entidad_id = $1 RETURNING storage_path",
        [fincaId],
      );
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
              f.geo_hash AS "geoHash", f.deforestacion, f.attestation_uid AS "attestationUid"
       FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE p.organizacion_id = $1 ORDER BY f.creado_en`,
      [organizacionId],
    );
    const entregas = await this.pool.query(
      `SELECT e.id, e.finca_id AS "fincaId", e.kg::float8 AS kg, e.estado, e.fecha, e.attestation_uid AS "attestationUid"
       FROM entregas e JOIN fincas f ON f.id = e.finca_id JOIN productores p ON p.id = f.productor_id
       WHERE p.organizacion_id = $1 ORDER BY e.fecha`,
      [organizacionId],
    );
    return {
      productores: productores.rows,
      fincas: fincas.rows.map(({ geom, ...f }) => ({ ...f, coordenadas: desdeGeometria(geom) })),
      entregas: entregas.rows.map((e) => ({ ...e, fecha: new Date(e.fecha).toISOString() })),
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
