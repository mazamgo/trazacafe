import { randomUUID } from "node:crypto";
import type pg from "pg";
import { z } from "zod";

/**
 * Base del cobro (Fase 4): lo acordado con cada organización (`contratos`) y
 * lo que se cobra (`consumos`, migración 014). Lo que se cobra es el
 * contenedor **cerrado**: solo se cierra con número de contenedor y todas las
 * fincas en verde, no se deshace y queda firmado en la blockchain.
 *
 * Modelo (hipótesis del piloto): cuota del período pagada por adelantado con
 * una bolsa de contenedores incluidos, y cada contenedor adicional al precio
 * del contrato. Sirve también para "solo cuota" (precio 0) o "solo por
 * contenedor" (cuota 0, bolsa 0).
 */

export const PLANES = ["basico", "exportador", "comprador"] as const;
export const ESTADOS_CONTRATO = ["prueba", "activo", "en_mora", "suspendido"] as const;

const fecha = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "usa el formato AAAA-MM-DD");
const usd = z.coerce.number().nonnegative().multipleOf(0.01);

export const contratoSchema = z
  .object({
    organizacionId: z.uuid(),
    plan: z.enum(PLANES),
    inicio: fecha,
    fin: fecha,
    cuotaUsd: usd.default(0),
    contenedoresIncluidos: z.coerce.number().int().nonnegative().default(0),
    precioContenedorUsd: usd.default(0),
    estado: z.enum(ESTADOS_CONTRATO).default("prueba"),
    nota: z.string().trim().max(500).optional(),
  })
  .refine((c) => c.inicio < c.fin, { message: "el fin debe ser después del inicio", path: ["fin"] });
export type ContratoNuevo = z.infer<typeof contratoSchema>;

export const ajusteSchema = z.object({
  organizacionId: z.uuid(),
  montoUsd: z.coerce
    .number()
    .multipleOf(0.01)
    .refine((m) => m !== 0, "el monto no puede ser 0"),
  motivo: z.string().trim().min(3).max(500),
});
export type AjusteNuevo = z.infer<typeof ajusteSchema>;

/**
 * Anota el contenedor cerrado como consumo, con el precio del contrato vigente
 * congelado. Va en la misma transacción que el cierre (`repo.cerrarExportacion`).
 */
export async function registrarContenedorEnTx(
  c: pg.PoolClient,
  organizacionId: string,
  exportacionId: string,
  uid: string,
): Promise<void> {
  await c.query(
    `INSERT INTO consumos (id, organizacion_id, tipo, contrato_id, exportacion_id, codigo, numero_contenedor,
                           cultivo, kg, precio_usd, creado_por)
     SELECT $1, x.organizacion_id, 'contenedor', ct.id, x.id, x.codigo, x.contenedor, x.cultivo,
            coalesce((SELECT sum(l.kg) FROM exportacion_lotes el JOIN lotes l ON l.id = el.lote_id
                      WHERE el.exportacion_id = x.id), 0),
            ct.precio_contenedor_usd, $4
     FROM exportaciones x
     LEFT JOIN contratos ct ON ct.organizacion_id = x.organizacion_id
       AND (now() AT TIME ZONE 'America/Managua')::date BETWEEN ct.inicio AND ct.fin
     WHERE x.id = $2 AND x.organizacion_id = $3
     ON CONFLICT DO NOTHING`,
    [randomUUID(), exportacionId, organizacionId, uid],
  );
}

export interface ContratoCobro {
  id: string;
  plan: string;
  inicio: string;
  fin: string;
  cuotaUsd: number;
  contenedoresIncluidos: number;
  precioContenedorUsd: number;
  estado: string;
}

export interface ConsumoCobro {
  id: string;
  tipo: "contenedor" | "ajuste";
  fecha: Date;
  contratoId: string | null;
  codigo: string | null;
  numeroContenedor: string | null;
  cultivo: string | null;
  kg: number | null;
  precioUsd: number | null;
  montoUsd: number | null;
  motivo: string | null;
  attestationUid: string | null;
}

export interface LineaContenedor extends ConsumoCobro {
  /** Entra en la bolsa del contrato (no se cobra aparte). */
  incluido: boolean;
  /** Lo que se cobra por este contenedor: 0 si va en la bolsa; `null` sin contrato. */
  cobroUsd: number | null;
}

export interface EstadoDeCuenta {
  mes: string;
  contratos: {
    contrato: ContratoCobro;
    /** La cuota se factura en el mes en que empieza el contrato. */
    cuotaEsteMes: boolean;
    /** Contenedores de la bolsa usados hasta el final del mes. */
    usados: number;
    quedan: number;
  }[];
  contenedores: LineaContenedor[];
  ajustes: ConsumoCobro[];
  /** Contenedores cerrados sin contrato vigente: hay que acordar su precio. */
  sinContrato: number;
  totalUsd: number;
}

/** Mes (AAAA-MM) de una fecha en Nicaragua (UTC-6, sin horario de verano). */
export const mesEnNicaragua = (d: Date) => new Date(d.getTime() - 6 * 3_600_000).toISOString().slice(0, 7);

const centavos = (n: number) => Math.round(n * 100) / 100;

/**
 * Estado de cuenta de una organización para un mes. [consumos] trae todos
 * los contenedores de sus [contratos] hasta el final del mes (para saber
 * cuántos de la bolsa ya se usaron), y los ajustes y contenedores sin
 * contrato del mes.
 */
export function estadoDeCuenta(mes: string, contratos: ContratoCobro[], consumos: ConsumoCobro[]): EstadoDeCuenta {
  const hasta = consumos.filter((c) => mesEnNicaragua(c.fecha) <= mes);
  const delMes = (c: ConsumoCobro) => mesEnNicaragua(c.fecha) === mes;
  const orden = (a: ConsumoCobro, b: ConsumoCobro) => a.fecha.getTime() - b.fecha.getTime() || a.id.localeCompare(b.id);

  const contenedores: LineaContenedor[] = [];
  const resumen = contratos.map((contrato) => {
    const suyos = hasta.filter((c) => c.tipo === "contenedor" && c.contratoId === contrato.id).sort(orden);
    suyos.forEach((c, i) => {
      if (!delMes(c)) return;
      const incluido = i < contrato.contenedoresIncluidos;
      contenedores.push({ ...c, incluido, cobroUsd: incluido ? 0 : (c.precioUsd ?? 0) });
    });
    const usados = Math.min(suyos.length, contrato.contenedoresIncluidos);
    return {
      contrato,
      cuotaEsteMes: contrato.inicio.slice(0, 7) === mes,
      usados,
      quedan: contrato.contenedoresIncluidos - usados,
    };
  });
  const sinContrato = hasta.filter((c) => c.tipo === "contenedor" && c.contratoId === null && delMes(c));
  for (const c of sinContrato) contenedores.push({ ...c, incluido: false, cobroUsd: null });
  contenedores.sort(orden);

  const ajustes = hasta.filter((c) => c.tipo === "ajuste" && delMes(c)).sort(orden);
  const totalUsd = centavos(
    resumen.reduce((s, r) => s + (r.cuotaEsteMes ? r.contrato.cuotaUsd : 0), 0) +
      contenedores.reduce((s, c) => s + (c.cobroUsd ?? 0), 0) +
      ajustes.reduce((s, a) => s + (a.montoUsd ?? 0), 0),
  );
  return { mes, contratos: resumen, contenedores, ajustes, sinContrato: sinContrato.length, totalUsd };
}

/** Consultas de la base para los contratos y el estado de cuenta. */
export class CobrosPg {
  constructor(private readonly pool: pg.Pool) {}

  /** `null` si se traslapa con otro contrato de la organización. */
  async crearContrato(c: ContratoNuevo, uid: string): Promise<string | null> {
    const id = randomUUID();
    try {
      await this.pool.query(
        `INSERT INTO contratos (id, organizacion_id, plan, inicio, fin, cuota_usd, contenedores_incluidos,
                                precio_contenedor_usd, estado, nota, creado_por)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
        [id, c.organizacionId, c.plan, c.inicio, c.fin, c.cuotaUsd, c.contenedoresIncluidos, c.precioContenedorUsd, c.estado, c.nota ?? null, uid],
      );
      return id;
    } catch (e) {
      if ((e as { code?: string }).code === "23P01") return null;
      throw e;
    }
  }

  async registrarAjuste(a: AjusteNuevo, uid: string): Promise<string> {
    const id = randomUUID();
    await this.pool.query(
      `INSERT INTO consumos (id, organizacion_id, tipo, contrato_id, monto_usd, motivo, creado_por)
       SELECT $1, $2, 'ajuste',
              (SELECT ct.id FROM contratos ct WHERE ct.organizacion_id = $2
                 AND (now() AT TIME ZONE 'America/Managua')::date BETWEEN ct.inicio AND ct.fin),
              $3, $4, $5`,
      [id, a.organizacionId, a.montoUsd, a.motivo, uid],
    );
    return id;
  }

  /** Organizaciones con contrato o consumos en el mes (o solo [organizacionId]). */
  async organizacionesDelMes(mes: string, organizacionId?: string): Promise<{ id: string; nombre: string }[]> {
    const { rows } = await this.pool.query<{ id: string; nombre: string }>(
      `SELECT o.id, o.nombre FROM organizaciones o
       WHERE ($2::uuid IS NULL OR o.id = $2)
         AND (EXISTS (SELECT 1 FROM contratos ct WHERE ct.organizacion_id = o.id
                        AND daterange(ct.inicio, ct.fin, '[]') && daterange(($1 || '-01')::date, (($1 || '-01')::date + interval '1 month')::date, '[)'))
              OR EXISTS (SELECT 1 FROM consumos c WHERE c.organizacion_id = o.id
                           AND to_char(c.fecha AT TIME ZONE 'America/Managua', 'YYYY-MM') = $1))
       ORDER BY o.nombre`,
      [mes, organizacionId ?? null],
    );
    return rows;
  }

  async estadoDeCuenta(organizacionId: string, mes: string): Promise<EstadoDeCuenta> {
    const { rows: contratos } = await this.pool.query<ContratoCobro>(
      `SELECT id, plan, to_char(inicio, 'YYYY-MM-DD') AS inicio, to_char(fin, 'YYYY-MM-DD') AS fin,
              cuota_usd::float8 AS "cuotaUsd", contenedores_incluidos AS "contenedoresIncluidos",
              precio_contenedor_usd::float8 AS "precioContenedorUsd", estado
       FROM contratos
       WHERE organizacion_id = $1
         AND daterange(inicio, fin, '[]') && daterange(($2 || '-01')::date, (($2 || '-01')::date + interval '1 month')::date, '[)')
       ORDER BY inicio`,
      [organizacionId, mes],
    );
    const { rows: consumos } = await this.pool.query<ConsumoCobro>(
      `SELECT id, tipo, fecha, contrato_id AS "contratoId", codigo, numero_contenedor AS "numeroContenedor", cultivo,
              kg::float8, precio_usd::float8 AS "precioUsd", monto_usd::float8 AS "montoUsd", motivo,
              attestation_uid AS "attestationUid"
       FROM consumos
       WHERE organizacion_id = $1
         AND to_char(fecha AT TIME ZONE 'America/Managua', 'YYYY-MM') <= $2
         AND (contrato_id = ANY($3::uuid[]) OR to_char(fecha AT TIME ZONE 'America/Managua', 'YYYY-MM') = $2)`,
      [organizacionId, mes, contratos.map((c) => c.id)],
    );
    return estadoDeCuenta(mes, contratos, consumos);
  }
}
