import { describe, expect, it } from "vitest";
import { aproximar, fincasPublicas, UID_VALIDO, type FilaEntrega, type FilaFinca } from "../src/verificador.ts";

const finca = (fincaId: string, lat: number, lon: number): FilaFinca => ({
  fincaId,
  firma: { uid: `0x${fincaId}`, txHash: null, firmadaEn: null },
  version: 1,
  areaHa: 2.345,
  lat,
  lon,
  deforestacion: "verde",
  chequeo: null,
  visita: null,
});
const entrega = (fincaId: string, kg: number, fecha: string): FilaEntrega => ({
  fincaId,
  uid: `0xe${kg}`,
  txHash: null,
  firmadaEn: null,
  kg,
  estado: "pergamino",
  fecha,
});

describe("verificador público", () => {
  it("redondea la ubicación a ~1 km", () => {
    expect(aproximar(13.630547)).toBe(13.63);
    expect(aproximar(-86.235912)).toBe(-86.24);
  });

  it("nombra las fincas por lo que aportan, sin ids internos, y ordena sus entregas por fecha", () => {
    const r = fincasPublicas(
      [finca("aaa", 13.6305, -86.2351), finca("bbb", 13.1111, -85.9999)],
      [entrega("aaa", 100, "2026-10-02"), entrega("bbb", 300, "2026-10-01"), entrega("aaa", 50, "2026-10-01")],
    );
    expect(r.map((f) => [f.alias, f.kg, f.ubicacion])).toEqual([
      ["Finca 1", 300, { lat: 13.11, lon: -86 }],
      ["Finca 2", 150, { lat: 13.63, lon: -86.24 }],
    ]);
    expect(r[1].entregas.map((e) => e.kg)).toEqual([50, 100]);
    expect(r[1].areaHa).toBe(2.35);
    expect(JSON.stringify(r)).not.toContain("fincaId");
  });

  it("solo acepta UIDs de 32 bytes", () => {
    expect(UID_VALIDO.test(`0x${"a".repeat(64)}`)).toBe(true);
    expect(UID_VALIDO.test("0xabc")).toBe(false);
    expect(UID_VALIDO.test(`0x${"a".repeat(64)}'; DROP`)).toBe(false);
  });
});
