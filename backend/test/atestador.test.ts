import { esquema, schemaUid } from "@trazacafe/eudr-eas-schemas";
import type { Hex } from "viem";
import { describe, expect, it } from "vitest";
import {
  agruparPorEsquema,
  procesarCola,
  type ColaAttestations,
  type Ola,
  type Pendiente,
  type RedEAS,
  type Solicitud,
} from "../src/atestador.ts";

const uid = (n: number) => `0x${n.toString(16).padStart(64, "0")}` as Hex;
const sol = (esquemaNombre: Solicitud["esquema"], n: number): Solicitud => ({ esquema: esquemaNombre, refUID: uid(0), data: uid(n) });
const pend = (esquemaNombre: Pendiente["esquema"], n: number): Pendiente => ({
  esquema: esquemaNombre,
  entidadId: `e${n}`,
  version: 1,
  colaId: n,
  solicitud: sol(esquemaNombre, n),
});

/** Cola en memoria: cada ola tiene lo que se le ponga; registra lo guardado. */
class ColaFalsa implements ColaAttestations {
  porOla: Record<Ola, Pendiente[]> = { 1: [], 2: [], 3: [], 4: [] };
  guardadas: { entidadId: string; uid: Hex; tx: Hex }[] = [];
  fallidas: { entidadId: string; error: string }[] = [];
  async listos(ola: Ola) {
    return this.porOla[ola];
  }
  async guardar(p: Pendiente[], uids: Hex[], tx: Hex) {
    p.forEach((x, i) => this.guardadas.push({ entidadId: x.entidadId, uid: uids[i], tx }));
  }
  async fallo(p: Pendiente[], error: string) {
    for (const x of p) this.fallidas.push({ entidadId: x.entidadId, error });
  }
}

/** Red falsa: devuelve un UID por solicitud; puede fallar en la llamada N. */
class RedFalsa implements RedEAS {
  nombre = "optimism-sepolia";
  llamadas: Solicitud[][] = [];
  fallarEn?: number;
  async atestar(s: Solicitud[]) {
    this.llamadas.push(s);
    if (this.llamadas.length === this.fallarEn) throw new Error("nonce too low");
    return { uids: s.map((x) => `0xa${x.data.slice(3)}` as Hex), txHash: uid(this.llamadas.length) };
  }
}

describe("procesarCola", () => {
  it("firma ola por ola, una transacción por ola, y salta las vacías", async () => {
    const cola = new ColaFalsa();
    cola.porOla[1] = [pend("Finca", 1), pend("Finca", 2)];
    cola.porOla[2] = [pend("Chequeo", 3), pend("Entrega", 4)];
    cola.porOla[4] = [pend("Exportacion", 5)];
    const red = new RedFalsa();
    const r = await procesarCola(cola, red);
    expect(red.llamadas.map((l) => l.map((s) => s.esquema))).toEqual([["Finca", "Finca"], ["Chequeo", "Entrega"], ["Exportacion"]]);
    expect(r).toEqual({ firmadas: { Finca: 2, Chequeo: 1, Entrega: 1, Exportacion: 1 }, transacciones: [uid(1), uid(2), uid(3)], error: null });
    expect(cola.guardadas.map((g) => g.entidadId)).toEqual(["e1", "e2", "e3", "e4", "e5"]);
  });

  it("si una ola falla, la marca, no guarda nada de ella y no sigue con las siguientes", async () => {
    const cola = new ColaFalsa();
    cola.porOla[1] = [pend("Finca", 1)];
    cola.porOla[2] = [pend("Entrega", 2)];
    cola.porOla[3] = [pend("Lote", 3)];
    const red = new RedFalsa();
    red.fallarEn = 2;
    const r = await procesarCola(cola, red);
    expect(r.error).toBe("nonce too low");
    expect(r.firmadas).toEqual({ Finca: 1 });
    expect(cola.guardadas.map((g) => g.entidadId)).toEqual(["e1"]);
    expect(cola.fallidas).toEqual([{ entidadId: "e2", error: "nonce too low" }]);
    expect(red.llamadas).toHaveLength(2);
  });

  it("sin nada listo no llama a la blockchain", async () => {
    const red = new RedFalsa();
    expect(await procesarCola(new ColaFalsa(), red)).toEqual({ firmadas: {}, transacciones: [], error: null });
    expect(red.llamadas).toHaveLength(0);
  });
});

describe("agruparPorEsquema", () => {
  it("agrupa por esquema y el orden devuelve cada evento a su solicitud", () => {
    const solicitudes = [sol("Chequeo", 1), sol("Entrega", 2), sol("Chequeo", 3), sol("Verificacion", 4)];
    const { pedido, orden } = agruparPorEsquema(solicitudes);
    const id = (n: Solicitud["esquema"]) => schemaUid(esquema(n).schema, esquema(n).revocable);
    expect(pedido.map((g) => g.schema)).toEqual([id("Chequeo"), id("Entrega"), id("Verificacion")]);
    expect(pedido[0].data.map((d) => d.data)).toEqual([uid(1), uid(3)]);
    // Eventos en el orden de los grupos: Chequeo 1, Chequeo 3, Entrega 2, Verificacion 4.
    expect(orden).toEqual([0, 2, 1, 3]);
    expect(pedido[0].data[0]).toMatchObject({ revocable: true, expirationTime: 0n, value: 0n });
  });
});
