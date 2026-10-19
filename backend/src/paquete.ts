import { cultivo } from "@trazacafe/eudr-eas-schemas";
import PDFDocument from "pdfkit";
import type { FincaDePaquete, Paquete } from "./repo.ts";

/** País de producción (ISO 3166-1 alfa-2). Por ahora solo Nicaragua. */
export const PAIS_PRODUCCION = "NI";

/**
 * Fincas de origen como FeatureCollection para la declaración de diligencia
 * debida (DDS) en TRACES: WGS84, al menos 6 decimales, un punto si la finca
 * mide menos de 4 ha y polígono si no. Propiedades según la descripción de
 * GeoJSON de TRACES (ProducerName, ProducerCountry, ProductionPlace, Area).
 * El nombre del productor es dato personal (Ley 787): solo va si se pide.
 */
export function geojsonTraces(fincas: FincaDePaquete[], { incluirProductor = false } = {}) {
  return {
    type: "FeatureCollection" as const,
    features: fincas.map((f) => ({
      type: "Feature" as const,
      geometry: f.geometria,
      properties: {
        ...(incluirProductor ? { ProducerName: f.productorNombre } : {}),
        ProducerCountry: PAIS_PRODUCCION,
        ProductionPlace: f.comunidad ? `${f.nombre}, ${f.comunidad}` : f.nombre,
        Area: Math.round(f.areaOficialHa * 10000) / 10000,
      },
    })),
  };
}

const NOMBRE_SATELITE: Record<string, string> = {
  pendiente: "sin chequeo",
  verde: "verde",
  amarillo: "amarillo (posible pérdida pequeña)",
  rojo: "rojo (pérdida de bosque)",
};

/**
 * Por qué el contenedor todavía no se puede cerrar, o lista vacía. Cerrar
 * significa que el paquete EUDR está completo: número de contenedor y todas
 * las fincas de origen sin deforestación después de 2020 según el satélite.
 */
export function motivosNoCierre(p: Paquete): string[] {
  const motivos: string[] = [];
  if (!p.exportacion.contenedor) motivos.push("Falta el número de contenedor");
  if (p.fincas.length === 0) motivos.push("El contenedor no tiene fincas de origen");
  const sinVerde = p.fincas.filter((f) => f.deforestacion !== "verde");
  if (sinVerde.length > 0) {
    const nombres = sinVerde.slice(0, 5).map((f) => `${f.nombre} (${NOMBRE_SATELITE[f.deforestacion]})`);
    motivos.push(
      `${sinVerde.length} ${sinVerde.length === 1 ? "finca no tiene" : "fincas no tienen"} chequeo satelital verde: ` +
        `${nombres.join(", ")}${sinVerde.length > 5 ? "…" : ""}`,
    );
  }
  return motivos;
}

const fechaCorta = (iso: string | null) => {
  if (!iso) return "—";
  const d = new Date(iso);
  // Día en Nicaragua (UTC-6, sin horario de verano).
  const ni = new Date(d.getTime() - 6 * 3600_000);
  return `${String(ni.getUTCDate()).padStart(2, "0")}/${String(ni.getUTCMonth() + 1).padStart(2, "0")}/${ni.getUTCFullYear()}`;
};
const kg = (n: number) => n.toLocaleString("en-US", { maximumFractionDigits: 0 });

/**
 * Resumen para el comprador en PDF (A4). No lleva nombres de productores:
 * fincas, comunidades, áreas oficiales, chequeo satelital, visitas, lotes y
 * huellas (geoHash) que luego se comprueban en la blockchain.
 */
export function pdfPaquete(p: Paquete, generado = new Date()): Promise<Buffer> {
  const x = p.exportacion;
  const c = cultivo(x.cultivo);
  const doc = new PDFDocument({ size: "A4", margin: 48, info: { Title: `Paquete EUDR ${x.codigo}`, Author: p.organizacion } });
  const partes: Buffer[] = [];
  doc.on("data", (b: Buffer) => partes.push(b));
  const listo = new Promise<Buffer>((resolve) => doc.on("end", () => resolve(Buffer.concat(partes))));

  const ancho = doc.page.width - 96;
  const titulo = (t: string) => {
    if (doc.y > doc.page.height - 140) doc.addPage();
    doc.moveDown(0.8).font("Helvetica-Bold").fontSize(12).fillColor("#2E4A2E").text(t, 48).moveDown(0.3);
    doc.font("Helvetica").fontSize(9.5).fillColor("black");
  };
  const fila = (etiqueta: string, valor: string) => {
    const y = doc.y;
    doc.font("Helvetica-Bold").text(etiqueta, 48, y, { width: 150 });
    doc.font("Helvetica").text(valor, 200, y, { width: ancho - 152 });
    doc.moveDown(0.15);
    doc.x = 48;
  };
  /** Tabla simple: columnas con ancho relativo; salta de página si no cabe. */
  const tabla = (columnas: { t: string; w: number }[], filas: string[][]) => {
    const total = columnas.reduce((s, col) => s + col.w, 0);
    const xs: number[] = [];
    let acum = 48;
    for (const col of columnas) {
      xs.push(acum);
      acum += (col.w / total) * ancho;
    }
    const anchoCol = (i: number) => (columnas[i].w / total) * ancho - 4;
    const dibujar = (celdas: string[], negrita: boolean) => {
      doc.font(negrita ? "Helvetica-Bold" : "Helvetica").fontSize(8.5);
      const alto = Math.max(...celdas.map((t, i) => doc.heightOfString(t, { width: anchoCol(i) }))) + 4;
      if (doc.y + alto > doc.page.height - 60) doc.addPage();
      const y = doc.y;
      celdas.forEach((t, i) => doc.text(t, xs[i], y + 2, { width: anchoCol(i) }));
      doc.y = y + alto;
      doc.moveTo(48, doc.y).lineTo(48 + ancho, doc.y).lineWidth(0.3).strokeColor("#BBBBBB").stroke();
    };
    dibujar(columnas.map((col) => col.t), true);
    for (const f of filas) dibujar(f, false);
    doc.x = 48;
    doc.fontSize(9.5);
  };

  doc.font("Helvetica-Bold").fontSize(16).text("Paquete de debida diligencia EUDR");
  doc.font("Helvetica").fontSize(10).fillColor("#555555")
    .text(`Reglamento (UE) 2023/1115 · Contenedor ${x.codigo} · ${p.organizacion}`);
  doc.fillColor("black");

  titulo("Envío");
  fila("Producto", `${c?.nombre ?? x.cultivo} (código SA ${c?.codigoHS ?? "—"})`);
  fila("Cantidad", `${kg(x.kg)} kg en ${x.lotes.length} ${x.lotes.length === 1 ? "lote" : "lotes"}`);
  fila("País de producción", "Nicaragua (NI)");
  fila("Exportador", p.organizacion);
  fila("Comprador", x.comprador);
  fila("Destino", x.destino);
  fila("Contenedor", x.contenedor ?? "pendiente");
  fila("Fecha de embarque", x.fechaEmbarque ? fechaCorta(`${x.fechaEmbarque}T12:00:00Z`) : "pendiente");
  fila("Referencia DDS (TRACES)", x.ddsRef ?? "pendiente");
  fila("Estado del paquete", x.estado === "cerrada" ? "Cerrado (completo)" : "Abierto (borrador)");

  titulo("Cumplimiento");
  const porEstado = (e: string) => p.fincas.filter((f) => f.deforestacion === e).length;
  const ha = p.fincas.reduce((s, f) => s + f.areaOficialHa, 0);
  fila("Fincas de origen", `${p.fincas.length} (${ha.toFixed(2)} ha oficiales, calculadas sobre el elipsoide WGS84)`);
  fila(
    "Deforestación",
    "Corte: 31/12/2020. Chequeo satelital contra el mapa de bosque 2020 de la Comisión Europea (JRC GFC2020) " +
      `y la pérdida anual de cobertura arbórea (Hansen/UMD): ${porEstado("verde")} verde, ` +
      `${porEstado("amarillo")} amarillo, ${porEstado("rojo")} rojo, ${porEstado("pendiente")} sin chequeo.`,
  );
  fila("Visitas de campo", `${p.fincas.filter((f) => f.ultimaVisita).length} de ${p.fincas.length} fincas con visita de verificación registrada.`);
  fila("Geolocalización", "Un punto para fincas de menos de 4 ha y polígono para las demás; el archivo GeoJSON del paquete trae las coordenadas completas.");
  const motivos = motivosNoCierre(p);
  if (motivos.length > 0) {
    doc.moveDown(0.3).font("Helvetica-Bold").fillColor("#B35C00").text("Pendiente para cerrar el paquete:");
    doc.font("Helvetica");
    for (const m of motivos) doc.text(`• ${m}`, { indent: 8 });
    doc.fillColor("black");
  }

  titulo("Lotes");
  tabla(
    [{ t: "Lote", w: 3 }, { t: "Temporada", w: 2 }, { t: "Estado", w: 2 }, { t: "Kg", w: 1.4 }],
    x.lotes.map((l) => [l.codigo, l.temporadaNombre, c?.estados.find((e) => e.id === l.estado)?.nombre ?? l.estado, kg(l.kg)]),
  );

  titulo("Fincas de origen");
  tabla(
    [
      { t: "Finca", w: 3 },
      { t: "Ha", w: 1 },
      { t: "Lindero", w: 1.6 },
      { t: "Satélite", w: 2.2 },
      { t: "Última visita", w: 1.6 },
      { t: "Kg", w: 1.2 },
      { t: "Huella (geoHash)", w: 2.4 },
    ],
    p.fincas.map((f) => [
      f.comunidad ? `${f.nombre} (${f.comunidad})` : f.nombre,
      f.areaOficialHa.toFixed(2),
      `${f.geometria.type === "Point" ? "Punto" : "Polígono"} v${f.version}`,
      `${NOMBRE_SATELITE[f.deforestacion]}${f.ultimoChequeo ? ` · ${fechaCorta(f.ultimoChequeo)}` : ""}`,
      fechaCorta(f.ultimaVisita),
      kg(f.kgEntregados),
      `${f.geoHash.slice(0, 14)}…`,
    ]),
  );

  titulo("Verificación");
  doc.text(
    "Cada finca, visita, entrega, lote y el contenedor se registran como attestations en la blockchain pública " +
      "OP Mainnet (Ethereum Attestation Service). La huella geoHash es el SHA-256 de las coordenadas: quien reciba el " +
      "GeoJSON puede recalcularla y compararla. En la blockchain no hay datos personales de los productores.",
  );
  if (x.attestationUid) fila("Attestation del contenedor", x.attestationUid);
  doc.moveDown(1).fontSize(8).fillColor("#777777")
    .text(`Generado por TrazaCafé el ${fechaCorta(generado.toISOString())}. Los productores firmaron su consentimiento de datos.`);
  doc.end();
  return listo;
}
