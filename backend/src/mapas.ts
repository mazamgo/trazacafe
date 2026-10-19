import { fromUrl, type GeoTIFFImage } from "geotiff";
import { CORTE_EUDR, type FuenteSatelital, type Hallazgos } from "./deforestacion.ts";
import type { FincaPorRevisar } from "./repo.ts";

/**
 * Mapas públicos para el chequeo de deforestación del EUDR, leídos por partes
 * (solo la ventana de cada finca) directamente de sus servidores:
 *
 * - JRC GFC2020 V4: bosque al 31/12/2020, ~10 m. Es el mapa de referencia de
 *   la Comisión Europea para el EUDR (CC BY 4.0).
 * - Hansen/UMD Global Forest Change v1.12: año de pérdida de cobertura
 *   arbórea 2001-2024, 30 m (CC BY 4.0). La tesela 20N_090W cubre Nicaragua.
 */
export const FUENTES_MAPAS = {
  bosque2020: "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/FOREST/GFC2020/LATEST/single-cog/JRC_GFC2020_V4_COG.tif",
  perdida: "https://storage.googleapis.com/earthenginepartners-hansen/GFC-2024-v1.12/Hansen_GFC-2024-v1.12_lossyear_20N_090W.tif",
};

/** Radio medio de la Tierra (el mismo de Turf y de la app). */
const RADIO_M = 6371008.8;

/** Ventana leída de un mapa: valores fila por fila desde la esquina noroeste. */
export interface Ventana {
  datos: ArrayLike<number>;
  ancho: number;
  alto: number;
  /** Longitud del borde oeste y latitud del borde norte del primer píxel. */
  oeste: number;
  norte: number;
  /** Tamaño del píxel en grados. */
  res: number;
}

/** Un mapa en EPSG:4326 del que se lee una caja [oeste, sur, este, norte]. */
export interface Mapa {
  leer(caja: [number, number, number, number]): Promise<Ventana>;
}

/** GeoTIFF (idealmente COG) remoto: solo se descargan los bloques de la caja. */
export class MapaRemoto implements Mapa {
  private imagen: Promise<GeoTIFFImage> | null = null;

  constructor(private readonly url: string) {}

  private abrir() {
    // Se abre una sola vez por proceso; si falla, se reintenta la próxima.
    this.imagen ??= fromUrl(this.url).then((t) => t.getImage());
    this.imagen.catch(() => (this.imagen = null));
    return this.imagen;
  }

  async leer([oeste, sur, este, norte]: [number, number, number, number]): Promise<Ventana> {
    const img = await this.abrir();
    const [ox, oy] = img.getOrigin();
    const res = Math.abs(img.getResolution()[0]);
    const x0 = Math.max(0, Math.floor((oeste - ox) / res));
    const y0 = Math.max(0, Math.floor((oy - norte) / res));
    const x1 = Math.min(img.getWidth(), Math.ceil((este - ox) / res));
    const y1 = Math.min(img.getHeight(), Math.ceil((oy - sur) / res));
    if (x1 <= x0 || y1 <= y0) throw new Error(`La finca está fuera de la cobertura de ${this.url}`);
    const [datos] = (await img.readRasters({ window: [x0, y0, x1, y1] })) as unknown as ArrayLike<number>[];
    return { datos, ancho: x1 - x0, alto: y1 - y0, oeste: ox + x0 * res, norte: oy - y0 * res, res };
  }
}

type Anillo = number[][];

/** Anillos de un Polygon o MultiPolygon GeoJSON, agrupados por polígono. */
function poligonos(g: FincaPorRevisar["geometria"]): Anillo[][] {
  const c = g.coordinates as Anillo[] | Anillo[][];
  return g.type === "Polygon" ? [c as Anillo[]] : (c as Anillo[][]);
}

/** Punto dentro de un anillo (rayo hacia el este). */
function dentroDeAnillo(x: number, y: number, anillo: Anillo): boolean {
  let dentro = false;
  for (let i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
    const [xi, yi] = anillo[i];
    const [xj, yj] = anillo[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) dentro = !dentro;
  }
  return dentro;
}

/** Dentro del polígono: dentro del anillo exterior y fuera de los huecos. */
export function dentro(x: number, y: number, g: FincaPorRevisar["geometria"]): boolean {
  return poligonos(g).some(([exterior, ...huecos]) => dentroDeAnillo(x, y, exterior) && !huecos.some((h) => dentroDeAnillo(x, y, h)));
}

function caja(g: FincaPorRevisar["geometria"]): [number, number, number, number] {
  let [oeste, sur, este, norte] = [Infinity, Infinity, -Infinity, -Infinity];
  for (const p of poligonos(g)) {
    for (const [x, y] of p[0]) {
      oeste = Math.min(oeste, x);
      este = Math.max(este, x);
      sur = Math.min(sur, y);
      norte = Math.max(norte, y);
    }
  }
  return [oeste, sur, este, norte];
}

/** Año de corte del EUDR (2020): la pérdida que cuenta es de 2021 en adelante. */
const ANIO_CORTE = Number(CORTE_EUDR.slice(0, 4));
const ha = (m2: number) => Math.round((m2 / 10000) * 10000) / 10000;

/**
 * Cruza los dos mapas dentro del lindero, píxel por píxel del mapa de bosque
 * (el más fino): bosque en 2020 (JRC = 1) y pérdida de 2021 en adelante
 * (Hansen: valor = año − 2000). Solo la pérdida de lo que era bosque en 2020
 * cuenta como deforestación para el EUDR; la otra se informa en el detalle.
 */
export async function analizar(geometria: FincaPorRevisar["geometria"], bosque: Mapa, perdida: Mapa) {
  const c = caja(geometria);
  const [vb, vp] = await Promise.all([bosque.leer(c), perdida.leer(c)]);
  let m2Finca = 0;
  let m2Bosque = 0;
  let m2PerdidaEnBosque = 0;
  let m2PerdidaFuera = 0;
  const porAnio: Record<number, number> = {};
  for (let fila = 0; fila < vb.alto; fila++) {
    const lat = vb.norte - (fila + 0.5) * vb.res;
    const radianes = (vb.res * Math.PI) / 180;
    const m2Pixel = radianes * RADIO_M * Math.cos((lat * Math.PI) / 180) * radianes * RADIO_M;
    const filaP = Math.floor((vp.norte - lat) / vp.res);
    for (let col = 0; col < vb.ancho; col++) {
      const lon = vb.oeste + (col + 0.5) * vb.res;
      if (!dentro(lon, lat, geometria)) continue;
      m2Finca += m2Pixel;
      const esBosque = vb.datos[fila * vb.ancho + col] === 1;
      if (esBosque) m2Bosque += m2Pixel;
      const colP = Math.floor((lon - vp.oeste) / vp.res);
      const anio = filaP >= 0 && filaP < vp.alto && colP >= 0 && colP < vp.ancho ? vp.datos[filaP * vp.ancho + colP] : 0;
      if (anio > 0 && 2000 + anio > ANIO_CORTE) {
        if (esBosque) {
          m2PerdidaEnBosque += m2Pixel;
          porAnio[2000 + anio] = (porAnio[2000 + anio] ?? 0) + m2Pixel;
        } else {
          m2PerdidaFuera += m2Pixel;
        }
      }
    }
  }
  return {
    haAnalizadas: ha(m2Finca),
    haBosque2020: ha(m2Bosque),
    haPerdidaEnBosque2020: ha(m2PerdidaEnBosque),
    haPerdidaFueraDeBosque2020: ha(m2PerdidaFuera),
    perdidaPorAnio: Object.fromEntries(Object.entries(porAnio).map(([a, m2]) => [a, ha(m2)])),
  };
}

/**
 * Chequeo satelital propio con mapas públicos: no necesita cuentas ni keys.
 * No tiene alertas casi en tiempo real (GLAD/RADD); Hansen se actualiza una
 * vez al año.
 */
export class MapasPublicos implements FuenteSatelital {
  nombre = "JRC GFC2020 V4 + Hansen/UMD GFC v1.12";

  constructor(
    private readonly bosque: Mapa = new MapaRemoto(FUENTES_MAPAS.bosque2020),
    private readonly perdida: Mapa = new MapaRemoto(FUENTES_MAPAS.perdida),
  ) {}

  async consultar(geometria: FincaPorRevisar["geometria"]): Promise<Hallazgos> {
    const r = await analizar(geometria, this.bosque, this.perdida);
    if (r.haAnalizadas === 0) throw new Error("El lindero es demasiado pequeño para los mapas (menos de un píxel)");
    return {
      alertas: 0,
      haAlertas: 0,
      haPerdida: r.haPerdidaEnBosque2020,
      detalle: { ...r, corte: CORTE_EUDR, fuentes: FUENTES_MAPAS },
    };
  }
}
