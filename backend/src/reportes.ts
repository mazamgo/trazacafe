import { convertirKg, cultivo as cultivoDe, estadoValido } from "@trazacafe/eudr-eas-schemas";
import type pg from "pg";
import type { EstadoDeforestacion } from "./repo.ts";
import { AREA_OFICIAL } from "./repo.ts";

/**
 * Reportes de la temporada para el administrador (Fase 3): avance de visitas,
 * estado satelital, alertas, kg por cultivo y lotes. Solo lectura.
 */

/** Finca activa de la temporada (sin las anonimizadas). */
export interface FincaReporte {
  id: string;
  nombre: string;
  productorId: string;
  productorNombre: string;
  comunidad: string | null;
  cultivo: string;
  geometria: unknown;
  areaOficialHa: number;
  deforestacion: EstadoDeforestacion;
  /** Último chequeo satelital: fecha ISO, fuente y área afectada. */
  ultimoChequeo: string | null;
  fuente: string | null;
  areaAfectadaHa: number | null;
  /** ¿Tiene visita de verificación en la temporada? */
  conVisita: boolean;
  kgEntregados: number;
}

/** Entregas de la temporada agrupadas por cultivo, estado y si van en un lote. */
export interface GrupoEntregas {
  cultivo: string;
  estado: string;
  enLote: boolean;
  kg: number;
  entregas: number;
}

export interface DatosReporte {
  temporada: { id: string; nombre: string; inicio: string; fin: string; cultivo: string | null };
  fincas: FincaReporte[];
  entregas: GrupoEntregas[];
  lotes: { abiertos: number; cerrados: number; vendidos: number; enContenedor: number; kg: number };
  /** Visitas de la temporada por persona (correo, o `null` si ya no está en el equipo). */
  visitas: { email: string | null; visitas: number }[];
}

export interface Reporte {
  temporada: DatosReporte["temporada"];
  resumen: {
    productores: number;
    fincas: number;
    areaOficialHa: number;
    conVisita: number;
    porcentajeVisita: number;
    verdes: number;
    porcentajeVerde: number;
    kgEntregados: number;
    entregas: number;
  };
  satelite: Record<EstadoDeforestacion, number>;
  /** Fincas en rojo, amarillo o sin chequeo (pendiente), las más graves primero. */
  alertas: FincaReporte[];
  sinVisita: Pick<FincaReporte, "id" | "nombre" | "productorNombre" | "comunidad">[];
  visitas: DatosReporte["visitas"];
  /** Kg por cultivo y estado, con su equivalente exportable (café oro, cacao seco). */
  kg: {
    cultivo: string;
    estado: string;
    kg: number;
    kgEnLotes: number;
    kgLibres: number;
    kgExportables: number;
    estadoExportable: string;
    entregas: number;
  }[];
  lotes: DatosReporte["lotes"];
}

const redondear = (n: number, decimales = 2) => Math.round(n * 10 ** decimales) / 10 ** decimales;
const porcentaje = (parte: number, total: number) => (total > 0 ? Math.round((parte * 100) / total) : 0);
const GRAVEDAD: Record<EstadoDeforestacion, number> = { rojo: 0, amarillo: 1, pendiente: 2, verde: 3 };

export function armarReporte(d: DatosReporte): Reporte {
  const satelite: Record<EstadoDeforestacion, number> = { verde: 0, amarillo: 0, rojo: 0, pendiente: 0 };
  for (const f of d.fincas) satelite[f.deforestacion]++;
  const conVisita = d.fincas.filter((f) => f.conVisita).length;

  const kg = new Map<string, Reporte["kg"][number]>();
  for (const g of d.entregas) {
    const c = cultivoDe(g.cultivo);
    const exportable = c?.estados.find((e) => e.factorExportable === 1);
    const clave = `${g.cultivo}/${g.estado}`;
    const fila = kg.get(clave) ?? {
      cultivo: g.cultivo,
      estado: g.estado,
      kg: 0,
      kgEnLotes: 0,
      kgLibres: 0,
      kgExportables: 0,
      estadoExportable: exportable?.id ?? g.estado,
      entregas: 0,
    };
    fila.kg += g.kg;
    fila[g.enLote ? "kgEnLotes" : "kgLibres"] += g.kg;
    fila.entregas += g.entregas;
    if (exportable && estadoValido(g.cultivo, g.estado)) {
      fila.kgExportables += convertirKg(g.cultivo, g.kg, g.estado, exportable.id);
    }
    kg.set(clave, fila);
  }

  return {
    temporada: d.temporada,
    resumen: {
      productores: new Set(d.fincas.map((f) => f.productorId)).size,
      fincas: d.fincas.length,
      areaOficialHa: redondear(d.fincas.reduce((s, f) => s + f.areaOficialHa, 0)),
      conVisita,
      porcentajeVisita: porcentaje(conVisita, d.fincas.length),
      verdes: satelite.verde,
      porcentajeVerde: porcentaje(satelite.verde, d.fincas.length),
      kgEntregados: redondear(d.entregas.reduce((s, g) => s + g.kg, 0)),
      entregas: d.entregas.reduce((s, g) => s + g.entregas, 0),
    },
    satelite,
    alertas: d.fincas
      .filter((f) => f.deforestacion !== "verde")
      .sort((a, b) => GRAVEDAD[a.deforestacion] - GRAVEDAD[b.deforestacion] || a.nombre.localeCompare(b.nombre, "es")),
    sinVisita: d.fincas
      .filter((f) => !f.conVisita)
      .map(({ id, nombre, productorNombre, comunidad }) => ({ id, nombre, productorNombre, comunidad })),
    visitas: d.visitas,
    kg: [...kg.values()].map((f) => ({
      ...f,
      kg: redondear(f.kg),
      kgEnLotes: redondear(f.kgEnLotes),
      kgLibres: redondear(f.kgLibres),
      kgExportables: redondear(f.kgExportables),
    })),
    lotes: d.lotes,
  };
}

const ESTADOS: Record<EstadoDeforestacion, string> = {
  verde: "Verde",
  amarillo: "Amarillo",
  rojo: "Rojo",
  pendiente: "Sin chequeo",
};

/** Un campo de CSV: entre comillas si lleva coma, comillas o salto de línea. */
function campo(v: string | number | null): string {
  const s = v === null ? "" : String(v);
  return /[",\r\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
}

/** Una fila por finca, para Excel: con BOM (tildes) y fin de línea de Windows. */
export function csvReporte(d: DatosReporte): string {
  const filas = [
    ["Productor", "Comunidad", "Finca", "Cultivo", "Área oficial (ha)", "Estado satelital", "Último chequeo", "Visita en la temporada", "Kg entregados"],
    ...d.fincas.map((f) => [
      f.productorNombre,
      f.comunidad,
      f.nombre,
      cultivoDe(f.cultivo)?.nombre ?? f.cultivo,
      redondear(f.areaOficialHa),
      ESTADOS[f.deforestacion],
      f.ultimoChequeo ? f.ultimoChequeo.slice(0, 10) : null,
      f.conVisita ? "Sí" : "No",
      redondear(f.kgEntregados),
    ]),
  ];
  return `﻿${filas.map((f) => f.map(campo).join(",")).join("\r\n")}\r\n`;
}

export interface Reportes {
  /** Datos de la temporada de la organización, o `null` si no es suya. */
  datos(organizacionId: string, temporadaId: string): Promise<DatosReporte | null>;
}

export class ReportesPg implements Reportes {
  constructor(private readonly pool: pg.Pool) {}

  async datos(organizacionId: string, temporadaId: string): Promise<DatosReporte | null> {
    const { rows: [t] } = await this.pool.query(
      `SELECT id, nombre, to_char(inicio, 'YYYY-MM-DD') AS inicio, to_char(fin, 'YYYY-MM-DD') AS fin, cultivo
       FROM temporadas WHERE id = $2 AND organizacion_id = $1`,
      [organizacionId, temporadaId],
    );
    if (!t) return null;
    const [fincas, entregas, lotes, visitas] = await Promise.all([
      this.pool.query(
        `SELECT f.id, f.nombre, p.id AS "productorId", p.nombre AS "productorNombre", p.comunidad, f.cultivo,
                ST_AsGeoJSON(f.geom, 7)::json AS geometria, ${AREA_OFICIAL("f")}::float8 AS "areaOficialHa",
                f.deforestacion, c.fecha AS "ultimoChequeo", c.fuente, c.area_afectada_ha::float8 AS "areaAfectadaHa",
                EXISTS (SELECT 1 FROM verificaciones v
                        WHERE v.finca_id = f.id AND v.temporada_id = $2 AND v.anulada_en IS NULL) AS "conVisita",
                coalesce((SELECT sum(e.kg) FROM entregas e
                          WHERE e.finca_id = f.id AND e.temporada_id = $2 AND e.anulada_en IS NULL), 0)::float8 AS "kgEntregados"
         FROM fincas f JOIN productores p ON p.id = f.productor_id
         LEFT JOIN LATERAL (SELECT fecha, fuente, area_afectada_ha FROM chequeos_deforestacion
                            WHERE finca_id = f.id ORDER BY fecha DESC LIMIT 1) c ON true
         WHERE p.organizacion_id = $1 AND p.anonimizado_en IS NULL AND f.anonimizada_en IS NULL
           AND ($3::text IS NULL OR f.cultivo = $3)
         ORDER BY p.nombre, f.nombre`,
        [organizacionId, temporadaId, t.cultivo],
      ),
      this.pool.query(
        `SELECT f.cultivo, e.estado, EXISTS (SELECT 1 FROM lote_entregas le WHERE le.entrega_id = e.id) AS "enLote",
                sum(e.kg)::float8 AS kg, count(*)::int AS entregas
         FROM entregas e JOIN fincas f ON f.id = e.finca_id JOIN productores p ON p.id = f.productor_id
         WHERE p.organizacion_id = $1 AND e.temporada_id = $2 AND e.anulada_en IS NULL
         GROUP BY 1, 2, 3 ORDER BY 1, 2`,
        [organizacionId, temporadaId],
      ),
      this.pool.query(
        `SELECT count(*) FILTER (WHERE l.cerrado_en IS NULL)::int AS abiertos,
                count(*) FILTER (WHERE l.cerrado_en IS NOT NULL)::int AS cerrados,
                count(*) FILTER (WHERE EXISTS (SELECT 1 FROM ventas_lotes v WHERE v.lote_id = l.id))::int AS vendidos,
                count(*) FILTER (WHERE EXISTS (SELECT 1 FROM exportacion_lotes el WHERE el.lote_id = l.id))::int AS "enContenedor",
                coalesce(sum(l.kg), 0)::float8 AS kg
         FROM lotes l WHERE l.organizacion_id = $1 AND l.temporada_id = $2`,
        [organizacionId, temporadaId],
      ),
      this.pool.query(
        `SELECT i.email, count(*)::int AS visitas
         FROM verificaciones v JOIN fincas f ON f.id = v.finca_id JOIN productores p ON p.id = f.productor_id
         LEFT JOIN invitaciones i ON i.usuario_uid = v.creado_por AND i.organizacion_id = $1
         WHERE p.organizacion_id = $1 AND v.temporada_id = $2 AND v.anulada_en IS NULL
         GROUP BY 1 ORDER BY 2 DESC, 1`,
        [organizacionId, temporadaId],
      ),
    ]);
    return {
      temporada: t,
      fincas: fincas.rows.map((f) => ({ ...f, ultimoChequeo: f.ultimoChequeo ? new Date(f.ultimoChequeo).toISOString() : null })),
      entregas: entregas.rows,
      lotes: lotes.rows[0],
      visitas: visitas.rows,
    };
  }
}
