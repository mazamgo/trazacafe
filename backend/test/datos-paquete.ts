import type { FincaDePaquete, Paquete } from "../src/repo.ts";

/** Datos de prueba del paquete EUDR (compartidos por paquete.test y app.test). */
export function fincaDePaquete(p: Partial<FincaDePaquete> = {}): FincaDePaquete {
  return {
    id: "f1",
    nombre: "La Leonesa",
    productorNombre: "Ana Pérez",
    comunidad: "San Rafael del Norte",
    geometria: { type: "Polygon", coordinates: [[[-86.1, 13.1], [-86.09, 13.1], [-86.09, 13.11], [-86.1, 13.1]]] },
    areaOficialHa: 4.19234,
    version: 2,
    geoHash: "0x2f95794d89008adc55fc3797ed22992bb737b4049d5a73383f7a02d79a2cdfe4",
    deforestacion: "verde",
    ultimoChequeo: "2026-10-20T12:00:00.000Z",
    ultimaVisita: "2026-10-16T17:00:00.000Z",
    attestationUid: null,
    kgEntregados: 500,
    ...p,
  };
}

export function paqueteDePrueba(p: { contenedor?: string | null; fincas?: FincaDePaquete[]; estado?: "abierta" | "cerrada" } = {}): Paquete {
  return {
    organizacion: "Cooperativa de Prueba R.L.",
    exportacion: {
      id: "x1",
      codigo: "EXP-2026-001",
      cultivo: "cafe",
      comprador: "Tostador GmbH",
      destino: "Hamburgo, Alemania",
      contenedor: p.contenedor === undefined ? "CSQU3054383" : p.contenedor,
      fechaEmbarque: "2026-11-20",
      ddsRef: null,
      estado: p.estado ?? "abierta",
      attestationUid: null,
      creadoEn: "2026-10-16T20:00:00.000Z",
      kg: 160,
      lotes: [{ id: "l1", codigo: "CAFE-2026/27-001", kg: 160, estado: "pergamino", temporadaNombre: "2026/27" }],
      resumen: { entregas: 2, fincas: 2, areaOficialHa: 5.6, fincasSinVerde: 0 },
    },
    fincas: p.fincas ?? [
      fincaDePaquete(),
      fincaDePaquete({ id: "f2", nombre: "XXX", comunidad: null, geometria: { type: "Point", coordinates: [-86.2, 13.2] }, areaOficialHa: 1.4, version: 1 }),
    ],
  };
}
