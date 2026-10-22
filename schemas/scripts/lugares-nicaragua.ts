/**
 * Genera app/assets/lugares_ni.json: las comunidades, comarcas, caseríos y
 * pueblos de Nicaragua en OpenStreetMap, con su municipio y departamento.
 * La app los usa para buscar en el mapa sin señal.
 *
 *   npm run lugares-nicaragua
 *
 * Usa la API pública de Overpass (tarda uno o dos minutos). Se corre de vez
 * en cuando y el resultado va al repositorio. Datos © colaboradores de
 * OpenStreetMap, licencia ODbL: la app muestra la atribución.
 */
import { writeFileSync } from "node:fs";

// Servidores públicos de Overpass: si uno está lleno se prueba el siguiente.
const OVERPASS = [
  "https://overpass-api.de/api/interpreter",
  "https://overpass.private.coffee/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
];
const TIPOS = "city|town|village|hamlet|locality|neighbourhood|suburb|isolated_dwelling";

type Elemento = { type: string; id: number; lat?: number; lon?: number; tags?: Record<string, string> };

async function consultar(q: string): Promise<Elemento[]> {
  for (let intento = 0; intento < 6; intento++) {
    const url = OVERPASS[intento % OVERPASS.length];
    const r = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "TrazaCafe/1.0 (GoProduction)" },
      body: new URLSearchParams({ data: q }),
    }).catch((e: Error) => ({ ok: false, status: 0, text: async () => e.message }) as Response);
    if (r.ok) return ((await r.json()) as { elements: Elemento[] }).elements;
    console.warn(`${url} respondió ${r.status}; reintento en ${10 * 2 ** intento} s`);
    await new Promise((listo) => setTimeout(listo, 10_000 * 2 ** intento));
  }
  throw new Error("Overpass no respondió");
}

const pais = `area["ISO3166-1"="NI"][admin_level=2]->.ni;`;

// 1. Municipio → departamento.
const departamentoDe = new Map<string, string>();
let departamento = "";
for (const e of await consultar(`[out:json][timeout:300];${pais}
rel(area.ni)["boundary"="administrative"]["admin_level"="4"];map_to_area->.deps;
foreach.deps->.d(.d out tags;rel(area.d)["boundary"="administrative"]["admin_level"="6"];out tags;);`)) {
  const nombre = e.tags?.name ?? "";
  if (e.type === "area") departamento = nombre.replace(/^Departamento de /, "");
  else departamentoDe.set(nombre, departamento);
}

// 2. Lugares de cada municipio.
const municipios: [string, string][] = [];
const lugares = new Map<number, [string, number, number, number]>();
let municipio = -1;
for (const e of await consultar(`[out:json][timeout:600];${pais}
rel(area.ni)["boundary"="administrative"]["admin_level"="6"];map_to_area->.muns;
foreach.muns->.m(.m out tags;node(area.m)["place"~"^(${TIPOS})$"]["name"];out body;);`)) {
  if (e.type === "area") {
    const nombre = e.tags?.name ?? "";
    municipios.push([nombre, departamentoDe.get(nombre) ?? ""]);
    municipio = municipios.length - 1;
  } else if (e.type === "node" && !lugares.has(e.id) && e.tags?.name && e.lat != null && e.lon != null) {
    const redondear = (n: number) => Math.round(n * 1e5) / 1e5;
    lugares.set(e.id, [e.tags.name.trim(), redondear(e.lat), redondear(e.lon), municipio]);
  }
}

const lista = [...lugares.values()].sort((a, b) => a[0].localeCompare(b[0], "es"));
writeFileSync(
  new URL("../../app/assets/lugares_ni.json", import.meta.url),
  JSON.stringify({ fuente: "© colaboradores de OpenStreetMap (ODbL)", municipios, lugares: lista }),
);
console.log(`${lista.length} lugares en ${municipios.length} municipios`);
