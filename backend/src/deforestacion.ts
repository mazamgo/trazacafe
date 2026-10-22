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
 * - amarillo: pérdida de menos de 0.1 ha (puede ser un error del satélite o
 *   una poda) o alertas de cualquier tamaño; lo revisa una persona;
 * - rojo: pérdida confirmada de 0.1 ha o más. Sus entregas no pueden ir a un
 *   lote de exportación.
 *
 * Las alertas nunca ponen rojo por sí solas: son un aviso temprano, no
 * distinguen la deforestación de otras perturbaciones (poda de sombra,
 * renovación del cafetal) y no saben qué era bosque en 2020. La pérdida anual
 * de Hansen las confirma o descarta.
 */
export function clasificar(h: Hallazgos): Chequeo["resultado"] {
  if (h.haPerdida >= UMBRAL_ROJO_HA) return "rojo";
  if (h.haPerdida > 0 || h.alertas > 0) return "amarillo";
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
    // Solo la pérdida confirmada: el área de las alertas va en el detalle.
    areaAfectadaHa: Number(h.haPerdida.toFixed(4)),
    resultado: clasificar(h),
    detalle: h.detalle,
  };
}

/**
 * Global Forest Watch Data API (data-api.globalforestwatch.org): solo las
 * alertas integradas (GLAD-L, GLAD-S2, RADD). La key es gratis y vence al año;
 * va en Secret Manager como GFW_API_KEY.
 */
export class GlobalForestWatch {
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

  /** Alertas integradas después del corte del EUDR dentro del polígono. */
  async alertas(geometria: FincaPorRevisar["geometria"]): Promise<{ alertas: number; ha: number }> {
    const r = await this.consulta(
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
    return { alertas: num(r.count), ha: num(r.ha) };
  }
}

/**
 * Modo combinado (SATELITE=gfw): los mapas públicos (JRC 2020 + Hansen)
 * deciden, como siempre, y las alertas de GFW avisan de lo reciente que
 * Hansen aún no publica. Las alertas solo se consultan si la finca tenía
 * bosque en 2020 según el JRC, y solo pueden llevarla a amarillo (ver
 * `clasificar`). Si GFW falla o la key venció, queda el resultado de los
 * mapas con el error en el detalle.
 */
export class MapasConAlertas implements FuenteSatelital {
  nombre: string;

  constructor(
    private readonly mapas: FuenteSatelital,
    private readonly gfw: GlobalForestWatch,
  ) {
    this.nombre = `${mapas.nombre} + alertas integradas de GFW`;
  }

  async consultar(geometria: FincaPorRevisar["geometria"]): Promise<Hallazgos> {
    const base = await this.mapas.consultar(geometria);
    if (!(Number(base.detalle.haBosque2020) > 0)) {
      return { ...base, detalle: { ...base.detalle, alertasGfw: "no se consultan: sin bosque en 2020 según el JRC" } };
    }
    try {
      const a = await this.gfw.alertas(geometria);
      return { ...base, alertas: a.alertas, haAlertas: a.ha, detalle: { ...base.detalle, alertasGfw: a } };
    } catch (e) {
      return { ...base, detalle: { ...base.detalle, alertasGfw: { error: (e as Error).message } } };
    }
  }
}
