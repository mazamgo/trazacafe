/**
 * Muestra la estructura de los mapas públicos (tamaño, resolución, bloques)
 * y lee la ventana de una coordenada: sirve para comprobar que se pueden
 * leer por partes, sin descargar el archivo entero.
 *
 *   npm run explorar-mapas -- -86.0018 13.0915
 */
import { fromUrl } from "geotiff";
import { FUENTES_MAPAS } from "../src/mapas.ts";

const [lon, lat] = process.argv.slice(2).map(Number);
for (const [nombre, url] of Object.entries(FUENTES_MAPAS)) {
  const inicio = Date.now();
  const tiff = await fromUrl(url);
  const img = await tiff.getImage();
  const [ox, oy] = img.getOrigin();
  const [rx, ry] = img.getResolution();
  console.log(
    `\n${nombre}\n  ${img.getWidth()}×${img.getHeight()} px, resolución ${rx.toFixed(7)}°, bloque ${img.getTileWidth()}×${img.getTileHeight()}, ` +
      `origen (${ox}, ${oy}), cabecera en ${Date.now() - inicio} ms`,
  );
  if (Number.isFinite(lon)) {
    const x = Math.floor((lon - ox) / rx);
    const y = Math.floor((lat - oy) / ry);
    const t = Date.now();
    const [banda] = (await img.readRasters({ window: [x - 25, y - 25, x + 25, y + 25] })) as unknown as Uint8Array[];
    const valores = new Map<number, number>();
    for (const v of banda) valores.set(v, (valores.get(v) ?? 0) + 1);
    console.log(`  ventana 50×50 en (${lon}, ${lat}) leída en ${Date.now() - t} ms → valores ${JSON.stringify([...valores].sort((a, b) => a[0] - b[0]))}`);
  }
}
