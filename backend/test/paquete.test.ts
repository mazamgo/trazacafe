import { describe, expect, it } from "vitest";
import { centroide, csvPlataformas, geojsonTraces, motivosNoCierre, pdfPaquete, wkt } from "../src/paquete.ts";
import { fincaDePaquete, paqueteDePrueba } from "./datos-paquete.ts";

describe("geojsonTraces", () => {
  it("una Feature por finca, con país, lugar y área, y sin el nombre del productor por defecto", () => {
    const g = geojsonTraces(paqueteDePrueba().fincas);
    expect(g.type).toBe("FeatureCollection");
    expect(g.features).toHaveLength(2);
    expect(g.features[0]).toEqual({
      type: "Feature",
      geometry: fincaDePaquete().geometria,
      properties: { ProducerCountry: "NI", ProductionPlace: "La Leonesa, San Rafael del Norte", Area: 4.1923 },
    });
    expect(g.features[1].geometry.type).toBe("Point");
    expect(g.features[1].properties.ProductionPlace).toBe("XXX");
  });

  it("incluye el nombre del productor solo si se pide", () => {
    const g = geojsonTraces(paqueteDePrueba().fincas, { incluirProductor: true });
    expect(g.features[0].properties).toMatchObject({ ProducerName: "Ana Pérez" });
  });
});

describe("motivosNoCierre", () => {
  it("un paquete con número de contenedor y todas las fincas en verde se puede cerrar", () => {
    expect(motivosNoCierre(paqueteDePrueba())).toEqual([]);
  });

  it("pide el número de contenedor y nombra las fincas que no están en verde", () => {
    const m = motivosNoCierre(
      paqueteDePrueba({
        contenedor: null,
        fincas: [fincaDePaquete(), fincaDePaquete({ nombre: "XXX", deforestacion: "pendiente" }), fincaDePaquete({ nombre: "Roja", deforestacion: "rojo" })],
      }),
    );
    expect(m[0]).toBe("Falta el número de contenedor");
    expect(m[1]).toBe("2 fincas no tienen chequeo satelital verde: XXX (sin chequeo), Roja (rojo (pérdida de bosque))");
  });
});

describe("pdfPaquete", () => {
  it("genera un PDF válido de una o más páginas, también con muchas fincas", async () => {
    const pdf = await pdfPaquete(paqueteDePrueba());
    expect(pdf.subarray(0, 5).toString()).toBe("%PDF-");
    expect(pdf.length).toBeGreaterThan(2000);

    const muchas = Array.from({ length: 80 }, (_, i) => fincaDePaquete({ id: `f${i}`, nombre: `Finca ${i}`, deforestacion: i % 3 ? "verde" : "pendiente" }));
    const grande = await pdfPaquete(paqueteDePrueba({ fincas: muchas }));
    const paginas = grande.toString("latin1").match(/\/Type \/Page\b/g)?.length ?? 0;
    expect(paginas).toBeGreaterThan(1);
  });
});

describe("CSV para osapiens y Fairtrace", () => {
  it("una fila por finca con WKT, centroide, HS y el contenedor", () => {
    const lineas = csvPlataformas(paqueteDePrueba({ estado: "cerrada", proveedores: ["Coop Sur"] })).trimEnd().split("\r\n");
    expect(lineas[0].startsWith("\uFEFFplot_id,production_place,producer_name,supplier,country,commodity,hs_code,area_ha,latitude,longitude")).toBe(true);
    expect(lineas).toHaveLength(3);
    expect(lineas[1]).toContain('f1,"La Leonesa, San Rafael del Norte",,Cooperativa de Prueba R.L.,NI,Café,0901,4.1923,');
    expect(lineas[1]).toContain('Polygon,"POLYGON ((-86.1 13.1, -86.09 13.1, -86.09 13.11, -86.1 13.1))",verde,2026-10-20,2026-10-16,,500,EXP-2026-001,CSQU3054383');
    expect(lineas[2]).toContain(",13.2,-86.2,Point,POINT (-86.2 13.2),");
  });

  it("los nombres de productores solo si se piden", () => {
    expect(csvPlataformas(paqueteDePrueba(), { incluirProductor: true }).split("\r\n")[1]).toContain(",Ana Pérez,");
  });

  it("centroide y WKT de punto, polígono y multipolígono", () => {
    expect(centroide({ type: "Point", coordinates: [-86, 13] })).toEqual([-86, 13]);
    const c = centroide({ type: "Polygon", coordinates: [[[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]]] });
    expect(c).toEqual([1, 1]);
    expect(wkt({ type: "MultiPolygon", coordinates: [[[[0, 0], [1, 0], [1, 1], [0, 0]]], [[[5, 5], [6, 5], [6, 6], [5, 5]]]] })).toBe(
      "MULTIPOLYGON (((0 0, 1 0, 1 1, 0 0)), ((5 5, 6 5, 6 6, 5 5)))",
    );
  });
});
