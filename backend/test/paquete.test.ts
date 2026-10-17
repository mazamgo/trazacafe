import { describe, expect, it } from "vitest";
import { geojsonTraces, motivosNoCierre, pdfPaquete } from "../src/paquete.ts";
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
