import type pg from "pg";
import type { LoteSync } from "./sync.ts";

export class AccesoDenegado extends Error {}

export interface Repo {
  /** Guarda (idempotente) lo que llega de la app y encola las attestations. */
  guardarSync(cooperativaId: string, datos: LoteSync): Promise<void>;
}

export class PgRepo implements Repo {
  constructor(private readonly pool: pg.Pool) {}

  async guardarSync(cooperativaId: string, { productores, fincas, fotos }: LoteSync): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      for (const p of productores) {
        await client.query(
          `INSERT INTO productores (id, cooperativa_id, nombre, cedula, comunidad, consentimiento_firmado)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, cedula = EXCLUDED.cedula,
             comunidad = EXCLUDED.comunidad
           WHERE productores.cooperativa_id = EXCLUDED.cooperativa_id`,
          [p.id, cooperativaId, p.nombre, p.cedula ?? null, p.comunidad ?? null, p.consentimientoFirmado],
        );
      }
      for (const f of fincas) {
        const propio = await client.query(
          "SELECT 1 FROM productores WHERE id = $1 AND cooperativa_id = $2",
          [f.productorId, cooperativaId],
        );
        if (propio.rowCount === 0) throw new AccesoDenegado(`Productor ${f.productorId} no pertenece a la cooperativa`);

        // Una finca ya registrada no se modifica: su geoHash pudo ya atestarse.
        await client.query(
          `INSERT INTO fincas (id, productor_id, nombre, geom, area_ha, geo_hash)
           VALUES ($1, $2, $3, ST_SetSRID(ST_GeomFromGeoJSON($4), 4326), $5, $6)
           ON CONFLICT (id) DO NOTHING`,
          [f.id, f.productorId, f.nombre, JSON.stringify(aGeometria(f.coordenadas)), f.areaHa, f.geoHash],
        );
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Finca', $1)
           ON CONFLICT DO NOTHING`,
          [f.id],
        );
      }
      for (const foto of fotos) {
        const propia = await client.query(
          foto.entidadTipo === "productor"
            ? "SELECT 1 FROM productores WHERE id = $1 AND cooperativa_id = $2"
            : `SELECT 1 FROM fincas f JOIN productores p ON p.id = f.productor_id
               WHERE f.id = $1 AND p.cooperativa_id = $2`,
          [foto.entidadId, cooperativaId],
        );
        if (propia.rowCount === 0) {
          throw new AccesoDenegado(`${foto.entidadTipo} ${foto.entidadId} no pertenece a la cooperativa`);
        }
        await client.query(
          `INSERT INTO fotos (id, cooperativa_id, entidad_tipo, entidad_id, tipo, sha256)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO NOTHING`,
          [foto.id, cooperativaId, foto.entidadTipo, foto.entidadId, foto.tipo, foto.sha256],
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
}

/** Un punto si hay una coordenada; si no, un polígono con el anillo cerrado. */
export function aGeometria(coords: [number, number][]) {
  if (coords.length === 1) return { type: "Point", coordinates: coords[0] };
  return { type: "Polygon", coordinates: [[...coords, coords[0]]] };
}
