/**
 * Arma un paquete de mapa satelital para usar sin señal (MBTiles con JPEG),
 * a partir de imágenes Sentinel-2 L2A de Copernicus (gratis, también para uso
 * comercial, citando "Contains modified Copernicus Sentinel data").
 *
 *   npm run mapa-sentinel -- --id jinotega --nombre "Jinotega (zona cafetalera)" \
 *     --bbox -86.30,12.95,-85.30,13.85 --desde 2026-01-01 --hasta 2026-04-30
 *
 * - Toma las escenas de la época seca con menos nubes (catálogo público de
 *   AWS, Element84 Earth Search) y arma un mosaico sin nubes: cada píxel sale
 *   de la escena más despejada en la que no hay nube ni sombra (banda SCL).
 * - Lee solo las partes necesarias de cada imagen (COG por rangos HTTP).
 * - Escribe zooms --zmin a --zmax (14 ≈ 10 m por píxel, la resolución real de
 *   Sentinel-2) en `--salida` (por defecto app/web/mapas/<id>.mbtiles) y
 *   actualiza `indice.json` en esa carpeta, que es lo que lee la app.
 *
 * La carpeta app/web/mapas/ no va al repositorio (pesa decenas de MB): se
 * publica con Firebase Hosting (`flutter build web` la copia a build/web).
 */
import { mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { fromUrl, type GeoTIFFImage } from "geotiff";
import jpeg from "jpeg-js";
import proj4 from "proj4";

const STAC = "https://earth-search.aws.element84.com/v1/search";
const TAM = 256;
// Bloque de trabajo: un tile de este zoom y todos sus hijos hasta --zmax.
const Z_BLOQUE = 11;
// SCL: 0 sin datos, 1 saturado, 3 sombra de nube, 7 sin clasificar (suele
// ser borde de nube), 8-10 nubes y cirros.
const SCL_MALO = new Set([0, 1, 3, 7, 8, 9, 10]);
// Además, un píxel casi blanco es nube aunque la SCL no la haya marcado.
const BLANCO = 160;

const { values } = parseArgs({
  options: {
    id: { type: "string" },
    nombre: { type: "string" },
    bbox: { type: "string" },
    desde: { type: "string" },
    hasta: { type: "string" },
    nubes: { type: "string", default: "70" },
    zmin: { type: "string", default: "8" },
    zmax: { type: "string", default: "14" },
    calidad: { type: "string", default: "75" },
    salida: { type: "string" },
    // Sigue un paquete que se cortó (p. ej. por la red): no rehace los bloques listos.
    continuar: { type: "boolean", default: false },
  },
});
if (!values.id || !values.nombre || !values.bbox || !values.desde || !values.hasta || !/^[a-z0-9-]+$/.test(values.id)) {
  console.error("Uso: npm run mapa-sentinel -- --id <id> --nombre <nombre> --bbox oeste,sur,este,norte --desde AAAA-MM-DD --hasta AAAA-MM-DD");
  process.exit(1);
}
const [oeste, sur, este, norte] = values.bbox.split(",").map(Number);
const zmin = Number(values.zmin);
const zmax = Number(values.zmax);
const salida = values.salida ?? fileURLToPath(new URL(`../../app/web/mapas/${values.id}.mbtiles`, import.meta.url));

// --- Web Mercator ---
const lon2x = (lon: number, z: number) => ((lon + 180) / 360) * 2 ** z;
const lat2y = (lat: number, z: number) => {
  const r = (lat * Math.PI) / 180;
  return ((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * 2 ** z;
};
const x2lon = (x: number, z: number) => (x / 2 ** z) * 360 - 180;
const y2lat = (y: number, z: number) => (Math.atan(Math.sinh(Math.PI * (1 - (2 * y) / 2 ** z))) * 180) / Math.PI;

/**
 * Reintenta una lectura por la red (cortes de conexión con S3). [reabrir] se
 * llama antes de cada reintento: geotiff.js guarda en su caché el bloque que
 * falló, así que hay que abrir la imagen de nuevo.
 */
async function conReintentos<T>(leer: () => Promise<T>, reabrir?: () => Promise<void>): Promise<T> {
  for (let intento = 1; ; intento++) {
    try {
      return await leer();
    } catch (e) {
      if (intento >= 6) throw e;
      console.warn(`  lectura falló (${(e as Error).message}); reintento ${intento} en ${intento * 5} s`);
      await new Promise((listo) => setTimeout(listo, intento * 5000));
      await reabrir?.().catch(() => {});
    }
  }
}

// --- Escenas ---
interface Escena {
  id: string;
  urls: { visual: string; scl: string };
  nubes: number;
  epsg: number;
  visual: GeoTIFFImage;
  scl: GeoTIFFImage;
  /** [xmin, ymin, xmax, ymax] en la proyección UTM de la escena. */
  caja: number[];
  aUtm: (lon: number, lat: number) => [number, number];
}

async function buscarEscenas(): Promise<{ id: string; nubes: number; epsg: number; visual: string; scl: string }[]> {
  const res = await fetch(STAC, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      collections: ["sentinel-2-l2a"],
      bbox: [oeste, sur, este, norte],
      datetime: `${values.desde}T00:00:00Z/${values.hasta}T23:59:59Z`,
      query: { "eo:cloud_cover": { lt: Number(values.nubes) } },
      sortby: [{ field: "properties.eo:cloud_cover", direction: "asc" }],
      limit: 100,
    }),
  });
  if (!res.ok) throw new Error(`Earth Search respondió ${res.status}`);
  const datos = (await res.json()) as {
    features: { id: string; properties: Record<string, unknown>; assets: Record<string, { href: string }> }[];
  };
  return datos.features.map((f) => ({
    id: f.id,
    nubes: Number(f.properties["eo:cloud_cover"]),
    epsg: Number(f.properties["proj:epsg"]),
    visual: f.assets.visual.href,
    scl: f.assets.scl.href,
  }));
}

const escenas: Escena[] = [];
async function abrir(e: Awaited<ReturnType<typeof buscarEscenas>>[number]): Promise<Escena> {
  const visual = await conReintentos(async () => (await fromUrl(e.visual)).getImage());
  const scl = await conReintentos(async () => (await fromUrl(e.scl)).getImage());
  const utm = `+proj=utm +zone=${e.epsg % 100} +datum=WGS84 +units=m +no_defs`;
  const conv = proj4("EPSG:4326", utm);
  return {
    id: e.id,
    urls: { visual: e.visual, scl: e.scl },
    nubes: e.nubes,
    epsg: e.epsg,
    visual,
    scl,
    caja: visual.getBoundingBox(),
    aUtm: (lon, lat) => conv.forward([lon, lat]) as [number, number],
  };
}

// --- Mosaico de un bloque (tile Z_BLOQUE) a resolución zmax ---
async function bloque(bx: number, by: number): Promise<Uint8Array | null> {
  const lado = 2 ** (zmax - Z_BLOQUE) * TAM;
  const rgb = new Uint8Array(lado * lado * 3);
  const listo = new Uint8Array(lado * lado); // 0 vacío, 1 con nube (provisional), 2 bueno
  // Píxeles provisionales: el más oscuro de los nublados (el menos nube).
  const brillo = new Uint16Array(lado * lado);
  const escala = 2 ** (zmax - Z_BLOQUE);
  // Lon/lat de cada columna y fila de píxel del bloque.
  const lons = Float64Array.from({ length: lado }, (_, i) => x2lon(bx * escala + (i + 0.5) / TAM, zmax));
  const lats = Float64Array.from({ length: lado }, (_, j) => y2lat(by * escala + (j + 0.5) / TAM, zmax));

  // UTM de cada píxel: exacto en una malla cada MALLA píxeles e interpolado
  // entre sus puntos (en 19 km la proyección es casi lineal; error < 1 m).
  const MALLA = 64;
  const n = lado / MALLA + 1;
  const utmDe = (e: Escena) => {
    const gx = new Float64Array(n * n);
    const gy = new Float64Array(n * n);
    for (let gj = 0; gj < n; gj++) {
      for (let gi = 0; gi < n; gi++) {
        const lon = x2lon(bx * escala + (gi * MALLA) / TAM, zmax);
        const lat = y2lat(by * escala + (gj * MALLA) / TAM, zmax);
        [gx[gj * n + gi], gy[gj * n + gi]] = e.aUtm(lon, lat);
      }
    }
    const ux = new Float64Array(lado * lado);
    const uy = new Float64Array(lado * lado);
    for (let j = 0; j < lado; j++) {
      const fj = (j + 0.5) / MALLA;
      const gj = Math.min(Math.floor(fj), n - 2);
      const tj = fj - gj;
      for (let i = 0; i < lado; i++) {
        const fi = (i + 0.5) / MALLA;
        const gi = Math.min(Math.floor(fi), n - 2);
        const ti = fi - gi;
        const a = gj * n + gi;
        const w00 = (1 - ti) * (1 - tj), w10 = ti * (1 - tj), w01 = (1 - ti) * tj, w11 = ti * tj;
        ux[j * lado + i] = gx[a] * w00 + gx[a + 1] * w10 + gx[a + n] * w01 + gx[a + n + 1] * w11;
        uy[j * lado + i] = gy[a] * w00 + gy[a + 1] * w10 + gy[a + n] * w01 + gy[a + n + 1] * w11;
      }
    }
    return { ux, uy };
  };

  for (const e of escenas) {
    if (listo.every((v) => v === 2)) break;
    // Caja UTM del bloque en esta escena (esquinas con margen).
    const esquinas = [
      e.aUtm(lons[0], lats[0]),
      e.aUtm(lons[lado - 1], lats[0]),
      e.aUtm(lons[0], lats[lado - 1]),
      e.aUtm(lons[lado - 1], lats[lado - 1]),
    ];
    const [cx0, cy0, cx1, cy1] = e.caja;
    const ux0 = Math.max(Math.min(...esquinas.map((c) => c[0])) - 20, cx0);
    const ux1 = Math.min(Math.max(...esquinas.map((c) => c[0])) + 20, cx1);
    const uy0 = Math.max(Math.min(...esquinas.map((c) => c[1])) - 20, cy0);
    const uy1 = Math.min(Math.max(...esquinas.map((c) => c[1])) + 20, cy1);
    if (ux0 >= ux1 || uy0 >= uy1) continue;

    const leer = async (cual: "visual" | "scl", res: number) => {
      const c0 = Math.floor((ux0 - cx0) / res);
      const c1 = Math.ceil((ux1 - cx0) / res);
      const f0 = Math.floor((cy1 - uy1) / res);
      const f1 = Math.ceil((cy1 - uy0) / res);
      const datos = (await conReintentos(
        () => e[cual].readRasters({ window: [c0, f0, c1, f1], interleave: true }),
        async () => {
          e[cual] = await (await fromUrl(e.urls[cual])).getImage();
        },
      )) as unknown as Uint8Array;
      return { datos, c0, f0, ancho: c1 - c0, alto: f1 - f0, res };
    };
    const v = await leer("visual", 10);
    const s = await leer("scl", 20);
    const { ux: uxs, uy: uys } = utmDe(e);
    // Nube con margen: un píxel de SCL (20 m) es malo si hay nube o sombra a
    // 2 píxeles o menos (~40 m); en ese borde queda bruma que la SCL no marca.
    const malo = new Uint8Array(s.ancho * s.alto);
    for (let f = 0; f < s.alto; f++) {
      for (let c = 0; c < s.ancho; c++) {
        if (!SCL_MALO.has(s.datos[f * s.ancho + c])) continue;
        for (let df = -2; df <= 2; df++) {
          for (let dc = -2; dc <= 2; dc++) {
            const ff = f + df;
            const cc = c + dc;
            if (ff >= 0 && cc >= 0 && ff < s.alto && cc < s.ancho) malo[ff * s.ancho + cc] = 1;
          }
        }
      }
    }

    for (let j = 0; j < lado; j++) {
      for (let i = 0; i < lado; i++) {
        const k = j * lado + i;
        if (listo[k] === 2) continue;
        const ux = uxs[k];
        const uy = uys[k];
        const vc = Math.floor((ux - cx0) / 10) - v.c0;
        const vf = Math.floor((cy1 - uy) / 10) - v.f0;
        if (vc < 0 || vf < 0 || vc >= v.ancho || vf >= v.alto) continue;
        const p = (vf * v.ancho + vc) * 3;
        const r = v.datos[p];
        const g = v.datos[p + 1];
        const b = v.datos[p + 2];
        if (r === 0 && g === 0 && b === 0) continue; // fuera de la órbita
        const sc = Math.floor((ux - cx0) / 20) - s.c0;
        const sf = Math.floor((cy1 - uy) / 20) - s.f0;
        const dentro = sc >= 0 && sf >= 0 && sc < s.ancho && sf < s.alto;
        const bueno = dentro && !malo[sf * s.ancho + sc] && !(r > BLANCO && g > BLANCO && b > BLANCO);
        if (bueno || listo[k] === 0 || r + g + b < brillo[k]) {
          rgb[k * 3] = r;
          rgb[k * 3 + 1] = g;
          rgb[k * 3 + 2] = b;
          brillo[k] = r + g + b;
          listo[k] = bueno ? 2 : 1;
        }
      }
    }
  }
  return listo.some((v) => v > 0) ? rgb : null;
}

/** Recorta un tile de un bloque y lo achica por 2^n (promedio). */
function tile(rgb: Uint8Array, lado: number, x0: number, y0: number, paso: number): Uint8Array {
  const out = new Uint8Array(TAM * TAM * 4);
  for (let j = 0; j < TAM; j++) {
    for (let i = 0; i < TAM; i++) {
      let r = 0,
        g = 0,
        b = 0;
      for (let dj = 0; dj < paso; dj++) {
        for (let di = 0; di < paso; di++) {
          const p = ((y0 + j * paso + dj) * lado + (x0 + i * paso + di)) * 3;
          r += rgb[p];
          g += rgb[p + 1];
          b += rgb[p + 2];
        }
      }
      const n = paso * paso;
      const q = (j * TAM + i) * 4;
      out[q] = r / n;
      out[q + 1] = g / n;
      out[q + 2] = b / n;
      out[q + 3] = 255;
    }
  }
  return out;
}
const aJpeg = (rgba: Uint8Array) =>
  jpeg.encode({ data: Buffer.from(rgba), width: TAM, height: TAM }, Number(values.calidad)).data;
const vacio = (rgba: Uint8Array) => {
  for (let p = 0; p < rgba.length; p += 4) if (rgba[p] || rgba[p + 1] || rgba[p + 2]) return false;
  return true;
};

// --- Principal ---
const encontradas = await buscarEscenas();
if (encontradas.length === 0) {
  console.error("No hay escenas con esos filtros.");
  process.exit(1);
}
console.log(`${encontradas.length} escenas (menos de ${values.nubes} % de nubes). Abriendo…`);
for (const e of encontradas) escenas.push(await abrir(e));
const anio = values.hasta.slice(0, 4);

mkdirSync(dirname(salida), { recursive: true });
const db = new DatabaseSync(salida);
if (!values.continuar) db.exec("DROP TABLE IF EXISTS tiles");
db.exec(`DROP TABLE IF EXISTS metadata;
  CREATE TABLE metadata (name text, value text);
  CREATE TABLE IF NOT EXISTS tiles (zoom_level integer, tile_column integer, tile_row integer, tile_data blob);
  CREATE UNIQUE INDEX IF NOT EXISTS tile_index ON tiles (zoom_level, tile_column, tile_row);`);
const tileGuardado = db.prepare("SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?");
const insertar = db.prepare("INSERT OR REPLACE INTO tiles VALUES (?, ?, ?, ?)");
// MBTiles usa filas TMS (de sur a norte).
const guardar = (z: number, x: number, y: number, rgba: Uint8Array) => {
  if (!vacio(rgba)) insertar.run(z, x, 2 ** z - 1 - y, aJpeg(rgba));
};

const bx0 = Math.floor(lon2x(oeste, Z_BLOQUE));
const bx1 = Math.floor(lon2x(este, Z_BLOQUE));
const by0 = Math.floor(lat2y(norte, Z_BLOQUE));
const by1 = Math.floor(lat2y(sur, Z_BLOQUE));
const total = (bx1 - bx0 + 1) * (by1 - by0 + 1);
const ladoBloque = 2 ** (zmax - Z_BLOQUE) * TAM;
// Los tiles de Z_BLOQUE se guardan para armar los zooms de abajo.
const bloques = new Map<string, Uint8Array>();
let hechos = 0;
const inicio = Date.now();
for (let by = by0; by <= by1; by++) {
  for (let bx = bx0; bx <= bx1; bx++) {
    // Con --continuar, un bloque ya guardado se lee de la base (se necesita
    // para armar los zooms de abajo) en lugar de rehacerlo.
    const listoAntes = values.continuar
      ? (tileGuardado.get(Z_BLOQUE, bx, 2 ** Z_BLOQUE - 1 - by) as { tile_data: Uint8Array } | undefined)
      : undefined;
    if (listoAntes) {
      bloques.set(`${bx},${by}`, new Uint8Array(jpeg.decode(listoAntes.tile_data, { useTArray: true }).data));
      hechos++;
      continue;
    }
    const rgb = await bloque(bx, by);
    hechos++;
    if (rgb) {
      db.exec("BEGIN");
      for (let z = zmax; z >= Z_BLOQUE; z--) {
        const n = 2 ** (z - Z_BLOQUE);
        const paso = ladoBloque / (n * TAM);
        for (let ty = 0; ty < n; ty++) {
          for (let tx = 0; tx < n; tx++) {
            const t = tile(rgb, ladoBloque, tx * TAM * paso, ty * TAM * paso, paso);
            guardar(z, bx * n + tx, by * n + ty, t);
            if (z === Z_BLOQUE) bloques.set(`${bx},${by}`, t);
          }
        }
      }
      db.exec("COMMIT");
    }
    const seg = (Date.now() - inicio) / 1000;
    console.log(`bloque ${hechos}/${total} (${Math.round(seg)} s, faltan ~${Math.round((seg / hechos) * (total - hechos))} s)`);
  }
}

// Zooms más alejados: 2x2 tiles del zoom de abajo → 1 tile.
let nivel = bloques;
for (let z = Z_BLOQUE - 1; z >= zmin; z--) {
  const siguiente = new Map<string, Uint8Array>();
  const padres = new Set([...nivel.keys()].map((k) => k.split(",").map((n) => Math.floor(Number(n) / 2)).join(",")));
  for (const clave of padres) {
    const [px, py] = clave.split(",").map(Number);
    const out = new Uint8Array(TAM * TAM * 4);
    for (const [dx, dy] of [[0, 0], [1, 0], [0, 1], [1, 1]]) {
      const hijo = nivel.get(`${px * 2 + dx},${py * 2 + dy}`);
      if (!hijo) continue;
      for (let j = 0; j < TAM / 2; j++) {
        for (let i = 0; i < TAM / 2; i++) {
          const q = ((dy * (TAM / 2) + j) * TAM + dx * (TAM / 2) + i) * 4;
          for (let c = 0; c < 3; c++) {
            let s = 0;
            for (const [a, b] of [[0, 0], [1, 0], [0, 1], [1, 1]]) s += hijo[((j * 2 + b) * TAM + i * 2 + a) * 4 + c];
            out[q + c] = s / 4;
          }
          out[q + 3] = 255;
        }
      }
    }
    guardar(z, px, py, out);
    siguiente.set(clave, out);
  }
  nivel = siguiente;
}

const atribucion = `Contains modified Copernicus Sentinel data ${anio}`;
const meta = db.prepare("INSERT INTO metadata VALUES (?, ?)");
for (const [k, v] of Object.entries({
  name: values.nombre,
  format: "jpg",
  type: "baselayer",
  version: "1",
  minzoom: String(zmin),
  maxzoom: String(zmax),
  bounds: `${oeste},${sur},${este},${norte}`,
  attribution: atribucion,
  description: `Sentinel-2 L2A, época seca ${values.desde} a ${values.hasta}, ${escenas.length} escenas`,
})) {
  meta.run(k, v);
}
const tiles = (db.prepare("SELECT count(*) AS n FROM tiles").get() as { n: number }).n;
db.close();

// Índice que lee la app (Mapas sin señal).
const bytes = statSync(salida).size;
const rutaIndice = join(dirname(salida), "indice.json");
let indice: { paquetes: Record<string, unknown>[] } = { paquetes: [] };
try {
  indice = JSON.parse(readFileSync(rutaIndice, "utf8"));
} catch {
  // Primero de la lista.
}
indice.paquetes = [
  ...indice.paquetes.filter((p) => p.id !== values.id),
  {
    id: values.id,
    nombre: values.nombre,
    archivo: `${values.id}.mbtiles`,
    bytes,
    bounds: [oeste, sur, este, norte],
    minzoom: zmin,
    maxzoom: zmax,
    imagenes: `${values.desde} a ${values.hasta}`,
    atribucion,
    generado: new Date().toISOString().slice(0, 10),
  },
];
writeFileSync(rutaIndice, `${JSON.stringify(indice, null, 2)}\n`);
console.log(`\n${tiles} tiles, ${(bytes / 1e6).toFixed(1)} MB → ${salida}`);
