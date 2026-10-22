import type { Chequeo, FincaPorRevisar } from "./repo.ts";

/** Fecha de corte del EUDR: no puede haber deforestación después de esta fecha. */
export const CORTE_EUDR = "2020-12-31";

/** Lo que dice el satélite sobre un polígono. */
export interface Hallazgos {
  /** Alertas integradas (GLAD-L, GLAD-S2, RADD) con confianza nominal, alta o máxima. */
  alertas: number;
  haAlertas: number;
  /** Pérdida anual de cobertura arbórea (Hansen/UMD) en años posteriores a 2020. */
  haPerdida: number;
  detalle: Record<string, unknown>;
}

export interface FuenteSatelital {
  nombre: string;
  consultar(geometria: FincaPorRevisar["geometria"]): Promise<Hallazgos>;
}

/** Por encima de esto (o de cualquier alerta en una zona de ese tamaño) la finca queda en rojo. */
export const UMBRAL_ROJO_HA = 0.1;

/**
 * Regla del semáforo:
 * - verde: el satélite no ve pérdida de bosque ni alertas después de 2020;
 * - amarillo: hay algo, pero menos de 0.1 ha (puede ser un error del
 *   satélite o una poda); lo revisa una persona;
 * - rojo: 0.1 ha o más. Sus entregas no pueden ir a un lote de exportación.
 */
export function clasificar(h: Hallazgos): Chequeo["resultado"] {
  const ha = Math.max(h.haAlertas, h.haPerdida);
  if (ha >= UMBRAL_ROJO_HA) return "rojo";
  if (ha > 0 || h.alertas > 0) return "amarillo";
  return "verde";
}

export async function revisar(fuente: FuenteSatelital, finca: FincaPorRevisar): Promise<Chequeo> {
  const h = await fuente.consultar(finca.geometria);
  return {
    fincaId: finca.fincaId,
    version: finca.version,
    temporadaId: finca.temporadaId,
    fuente: fuente.nombre,
    alertas: h.alertas,
    areaAfectadaHa: Number(Math.max(h.haAlertas, h.haPerdida).toFixed(4)),
    resultado: clasificar(h),
    detalle: h.detalle,
  };
}

/**
 * Global Forest Watch Data API (data-api.globalforestwatch.org). La key es
 * gratis y vence al año; va en Secret Manager como GFW_API_KEY.
 */
export class GlobalForestWatch implements FuenteSatelital {
  nombre = "Global Forest Watch (umd_tree_cover_loss + gfw_integrated_alerts)";

  constructor(
    private readonly apiKey: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  private async consulta(dataset: string, sql: string, geometria: unknown): Promise<Record<string, unknown>> {
    const res = await this.fetchFn(`https://data-api.globalforestwatch.org/dataset/${dataset}/latest/query/json`, {
      method: "POST",
      headers: { "x-api-key": this.apiKey, "Content-Type": "application/json" },
      body: JSON.stringify({ sql, geometry: geometria }),
    });
    if (!res.ok) throw new Error(`GFW ${dataset} respondió ${res.status}: ${(await res.text()).slice(0, 300)}`);
    const cuerpo = (await res.json()) as { data?: Record<string, unknown>[] };
    return cuerpo.data?.[0] ?? {};
  }

  async consultar(geometria: FincaPorRevisar["geometria"]): Promise<Hallazgos> {
    const perdida = await this.consulta(
      "umd_tree_cover_loss",
      // 30 % de cobertura es el umbral habitual de GFW para hablar de bosque.
      `SELECT SUM(area__ha) AS ha FROM results
       WHERE umd_tree_cover_loss__year > 2020 AND umd_tree_cover_density_2000__threshold >= 30`,
      geometria,
    );
    const alertas = await this.consulta(
      "gfw_integrated_alerts",
      // La API no acepta IN (responde 422) e ignora el alias de COUNT(*): el
      // conteo siempre llega como "count". Las confianzas son nominal, high y
      // highest; las tres cuentan.
      `SELECT COUNT(*), SUM(area__ha) AS ha FROM results
       WHERE gfw_integrated_alerts__date > '${CORTE_EUDR}'
         AND (gfw_integrated_alerts__confidence = 'nominal'
           OR gfw_integrated_alerts__confidence = 'high'
           OR gfw_integrated_alerts__confidence = 'highest')`,
      geometria,
    );
    const num = (v: unknown) => (typeof v === "number" ? v : Number(v ?? 0) || 0);
    return {
      alertas: num(alertas.count),
      haAlertas: num(alertas.ha),
      haPerdida: num(perdida.ha),
      detalle: { perdida, alertas, corte: CORTE_EUDR },
    };
  }
}
