import type pg from "pg";
import { AREA_OFICIAL } from "./repo.ts";

/**
 * Verificador público: lo que ve quien escanea el QR de un contenedor o de un
 * lote. Solo lo que ya está firmado en la blockchain y nada personal: sin
 * nombres de productores ni de fincas, sin cédulas, sin comprador, y la
 * ubicación redondeada a ~1 km.
 */

/** Una attestation: su UID, la transacción y cuándo se firmó. */
export interface Firma {
  uid: string;
  txHash: string | null;
  firmadaEn: string | null;
}

export interface CadenaPublica {
  /** `optimism-sepolia` u `optimism`. */
  red: string;
  /** Qué se escaneó. */
  tipo: "Exportacion" | "Lote";
  uid: string;
  /** Quien exporta el contenedor (o la dueña del lote escaneado). */
  organizacion: string;
  /** Otras organizaciones que vendieron lotes del contenedor (Fase 2b). */
  proveedores: string[];
  cultivo: string;
  exportacion: (Firma & {
    contenedor: string | null;
    destino: string;
    kg: number;
    ddsRef: string | null;
    fechaEmbarque: string | null;
  }) | null;
  lotes: (Firma & {
    /** Organización dueña del lote (solo su nombre). */
    organizacion: string;
    codigo: string;
    temporada: string;
    kg: number;
    estado: string;
    beneficio: string;
    proceso: string | null;
  })[];
  fincas: FincaPublica[];
}

export interface FincaPublica {
  /** "Finca 1", "Finca 2"…, de la que más aporta a la que menos. */
  alias: string;
  /** Attestation de su última versión de lindero firmada. */
  firma: Firma | null;
  version: number;
  areaHa: number;
  /** Redondeada a 2 decimales (~1 km). */
  ubicacion: { lat: number; lon: number };
  deforestacion: string;
  chequeo: (Firma & { resultado: string; fuente: string; fecha: string }) | null;
  visita: (Firma & { fecha: string }) | null;
  kg: number;
  entregas: (Firma & { kg: number; estado: string; fecha: string })[];
}

/** Redondea a ~1 km: suficiente para ver la zona, no para ubicar la casa del productor. */
export const aproximar = (grados: number) => Math.round(grados * 100) / 100;

export const UID_VALIDO = /^0x[0-9a-fA-F]{64}$/;

export interface Verificador {
  /** `null` si el UID no es de un contenedor o lote firmado. */
  cadena(uid: string): Promise<CadenaPublica | null>;
}

/** Filas de la base, antes de quitar lo personal y ordenar. */
export interface FilaFinca {
  fincaId: string;
  firma: Firma | null;
  version: number;
  areaHa: number;
  lat: number;
  lon: number;
  deforestacion: string;
  chequeo: CadenaPublica["fincas"][number]["chequeo"];
  visita: CadenaPublica["fincas"][number]["visita"];
}
export interface FilaEntrega extends Firma {
  fincaId: string;
  kg: number;
  estado: string;
  fecha: string;
}

/**
 * Junta fincas y entregas: las fincas se ordenan por kg aportados y se
 * nombran "Finca 1", "Finca 2"…; los ids internos no salen.
 */
export function fincasPublicas(fincas: FilaFinca[], entregas: FilaEntrega[]): FincaPublica[] {
  const kgDe = (id: string) => entregas.filter((e) => e.fincaId === id).reduce((s, e) => s + e.kg, 0);
  return [...fincas]
    .sort((a, b) => kgDe(b.fincaId) - kgDe(a.fincaId) || a.fincaId.localeCompare(b.fincaId))
    .map((f, i) => ({
      alias: `Finca ${i + 1}`,
      firma: f.firma,
      version: f.version,
      areaHa: Math.round(f.areaHa * 100) / 100,
      ubicacion: { lat: aproximar(f.lat), lon: aproximar(f.lon) },
      deforestacion: f.deforestacion,
      chequeo: f.chequeo,
      visita: f.visita,
      kg: Math.round(kgDe(f.fincaId) * 100) / 100,
      entregas: entregas
        .filter((e) => e.fincaId === f.fincaId)
        .map(({ fincaId: _, ...e }) => e)
        .sort((a, b) => a.fecha.localeCompare(b.fecha)),
    }));
}

const iso = (d: Date | string | null) => (d ? new Date(d).toISOString() : null);
const firma = (uid: string | null, txHash: string | null, en: Date | string | null): Firma | null =>
  uid ? { uid, txHash, firmadaEn: iso(en) } : null;

export class VerificadorPg implements Verificador {
  constructor(private readonly pool: pg.Pool) {}

  async cadena(uid: string): Promise<CadenaPublica | null> {
    if (!UID_VALIDO.test(uid)) return null;
    const { rows: [a] } = await this.pool.query(
      `SELECT esquema, entidad_id AS "entidadId", red, tx_hash AS "txHash", creado_en AS "creadoEn"
       FROM attestaciones WHERE lower(uid) = lower($1) AND esquema IN ('Exportacion', 'Lote')`,
      [uid],
    );
    if (!a) return null;

    let exportacion: CadenaPublica["exportacion"] = null;
    let loteIds: string[];
    let organizacion: string;
    let cultivo: string;
    if (a.esquema === "Exportacion") {
      const { rows: [x] } = await this.pool.query(
        `SELECT x.contenedor, x.destino, x.dds_ref AS "ddsRef", to_char(x.fecha_embarque, 'YYYY-MM-DD') AS "fechaEmbarque",
                x.cultivo, x.attestation_uid AS uid, o.nombre AS organizacion,
                (SELECT array_agg(el.lote_id) FROM exportacion_lotes el WHERE el.exportacion_id = x.id) AS lotes,
                (SELECT coalesce(sum(kg_en_contenedor(el.lote_id)), 0)::float8 FROM exportacion_lotes el
                 WHERE el.exportacion_id = x.id) AS kg
         FROM exportaciones x JOIN organizaciones o ON o.id = x.organizacion_id
         WHERE x.id = $1`,
        [a.entidadId],
      );
      // Si se revocara y volviera a firmar, solo vale la attestation vigente.
      if (!x || x.uid?.toLowerCase() !== uid.toLowerCase()) return null;
      exportacion = {
        uid: x.uid,
        txHash: a.txHash,
        firmadaEn: iso(a.creadoEn),
        contenedor: x.contenedor,
        destino: x.destino,
        kg: x.kg,
        ddsRef: x.ddsRef,
        fechaEmbarque: x.fechaEmbarque,
      };
      loteIds = x.lotes ?? [];
      organizacion = x.organizacion;
      cultivo = x.cultivo;
    } else {
      const { rows: [l] } = await this.pool.query(
        `SELECT l.cultivo, l.attestation_uid AS uid, o.nombre AS organizacion
         FROM lotes l JOIN organizaciones o ON o.id = l.organizacion_id WHERE l.id = $1`,
        [a.entidadId],
      );
      if (!l || l.uid?.toLowerCase() !== uid.toLowerCase()) return null;
      loteIds = [a.entidadId];
      organizacion = l.organizacion;
      cultivo = l.cultivo;
    }

    const { rows: lotes } = await this.pool.query(
      `SELECT l.attestation_uid AS uid, at.tx_hash AS "txHash", at.creado_en AS "firmadaEn", o.nombre AS organizacion,
              l.codigo, t.nombre AS temporada, l.kg::float8 AS kg, l.estado, l.beneficio, l.proceso
       FROM lotes l JOIN temporadas t ON t.id = l.temporada_id JOIN organizaciones o ON o.id = l.organizacion_id
       LEFT JOIN attestaciones at ON at.uid = l.attestation_uid
       WHERE l.id = ANY($1::uuid[]) ORDER BY l.codigo`,
      [loteIds],
    );
    const { rows: entregas } = await this.pool.query(
      `SELECT e.finca_id AS "fincaId", e.attestation_uid AS uid, at.tx_hash AS "txHash", at.creado_en AS "firmadaEn",
              e.kg::float8 AS kg, e.estado, e.fecha
       FROM lote_entregas le JOIN entregas e ON e.id = le.entrega_id
       LEFT JOIN attestaciones at ON at.uid = e.attestation_uid
       WHERE le.lote_id = ANY($1::uuid[]) AND e.anulada_en IS NULL`,
      [loteIds],
    );
    const fincaIds = [...new Set(entregas.map((e) => e.fincaId as string))];
    const { rows: fincas } = await this.pool.query(
      `SELECT f.id AS "fincaId", f.deforestacion, fv.version, fv.attestation_uid AS uid,
              fat.tx_hash AS "txHash", fat.creado_en AS "firmadaEn",
              ${AREA_OFICIAL("fv")}::float8 AS "areaHa",
              ST_Y(ST_PointOnSurface(fv.geom)) AS lat, ST_X(ST_PointOnSurface(fv.geom)) AS lon,
              (SELECT json_build_object('uid', c.attestation_uid, 'resultado', c.resultado, 'fuente', c.fuente,
                                        'fecha', c.fecha, 'txHash', cat.tx_hash, 'firmadaEn', cat.creado_en)
               FROM chequeos_deforestacion c LEFT JOIN attestaciones cat ON cat.uid = c.attestation_uid
               WHERE c.finca_id = f.id AND c.attestation_uid IS NOT NULL
               ORDER BY c.fecha DESC LIMIT 1) AS chequeo,
              (SELECT json_build_object('uid', v.attestation_uid, 'fecha', v.fecha,
                                        'txHash', vat.tx_hash, 'firmadaEn', vat.creado_en)
               FROM verificaciones v LEFT JOIN attestaciones vat ON vat.uid = v.attestation_uid
               WHERE v.finca_id = f.id AND v.attestation_uid IS NOT NULL AND v.anulada_en IS NULL
               ORDER BY v.fecha DESC LIMIT 1) AS visita
       FROM fincas f
       JOIN LATERAL (SELECT * FROM fincas_versiones v WHERE v.finca_id = f.id AND v.attestation_uid IS NOT NULL
                     ORDER BY v.version DESC LIMIT 1) fv ON true
       LEFT JOIN attestaciones fat ON fat.uid = fv.attestation_uid
       WHERE f.id = ANY($1::uuid[])`,
      [fincaIds],
    );

    return {
      red: a.red,
      tipo: a.esquema,
      uid,
      organizacion,
      proveedores: [...new Set(lotes.map((l) => l.organizacion as string))].filter((o) => o !== organizacion).sort(),
      cultivo,
      exportacion,
      lotes: lotes.map((l) => ({ ...l, firmadaEn: iso(l.firmadaEn) })),
      fincas: fincasPublicas(
        fincas.map((f) => ({
          fincaId: f.fincaId,
          firma: firma(f.uid, f.txHash, f.firmadaEn),
          version: f.version,
          areaHa: f.areaHa,
          lat: f.lat,
          lon: f.lon,
          deforestacion: f.deforestacion,
          chequeo: f.chequeo
            ? { ...f.chequeo, fecha: iso(f.chequeo.fecha)!, firmadaEn: iso(f.chequeo.firmadaEn) }
            : null,
          visita: f.visita ? { ...f.visita, fecha: iso(f.visita.fecha)!, firmadaEn: iso(f.visita.firmadaEn) } : null,
        })),
        entregas.map((e) => ({ ...e, fecha: iso(e.fecha)!, firmadaEn: iso(e.firmadaEn) })),
      ),
    };
  }
}
