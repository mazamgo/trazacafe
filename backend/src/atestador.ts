import {
  codificar,
  EAS_ADDRESS,
  esquema,
  hashDeHashes,
  kgX100,
  schemaUid,
  uuidABytes32,
  type NombreEsquema,
} from "@trazacafe/eudr-eas-schemas";
import type pg from "pg";
import { AREA_OFICIAL } from "./repo.ts";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseAbi,
  parseEventLogs,
  zeroAddress,
  zeroHash,
  type Chain,
  type Hex,
  type LocalAccount,
} from "viem";

/** Una attestation por firmar: esquema, a qué apunta (refUID) y sus datos ya codificados. */
export interface Solicitud {
  esquema: NombreEsquema;
  refUID: Hex;
  data: Hex;
}

/** Algo de la base listo para atestarse. */
export interface Pendiente {
  esquema: NombreEsquema;
  /** uuid de la entidad (o id numérico del chequeo). */
  entidadId: string;
  version: number;
  /** Fila de attestations_pendientes; `null` para los chequeos (no pasan por la cola). */
  colaId: number | null;
  solicitud: Solicitud;
}

/** La blockchain: firma un lote de attestations en una transacción. */
export interface RedEAS {
  /** `optimism-sepolia` u `optimism`. */
  nombre: string;
  /** UIDs en el mismo orden que [solicitudes]. */
  atestar(solicitudes: Solicitud[]): Promise<{ uids: Hex[]; txHash: Hex }>;
}

/** Olas en orden de dependencia: cada una apunta a attestations de las anteriores. */
export const OLAS = [1, 2, 3, 4] as const;
export type Ola = (typeof OLAS)[number];

export interface ColaAttestations {
  listos(ola: Ola, limite: number): Promise<Pendiente[]>;
  guardar(pendientes: Pendiente[], uids: Hex[], txHash: Hex, red: string): Promise<void>;
  fallo(pendientes: Pendiente[], error: string): Promise<void>;
}

export interface ResumenAtestador {
  firmadas: Partial<Record<NombreEsquema, number>>;
  transacciones: Hex[];
  error: string | null;
}

/**
 * Firma lo que está listo, ola por ola (una transacción por ola). Si una
 * ola falla, se marca el intento y se detiene: lo demás se reintenta en la
 * próxima ejecución.
 */
export async function procesarCola(cola: ColaAttestations, red: RedEAS, limite = 40): Promise<ResumenAtestador> {
  const resumen: ResumenAtestador = { firmadas: {}, transacciones: [], error: null };
  for (const ola of OLAS) {
    const pendientes = await cola.listos(ola, limite);
    if (pendientes.length === 0) continue;
    try {
      const { uids, txHash } = await red.atestar(pendientes.map((p) => p.solicitud));
      if (uids.length !== pendientes.length) throw new Error(`Se esperaban ${pendientes.length} UIDs y llegaron ${uids.length}`);
      await cola.guardar(pendientes, uids, txHash, red.nombre);
      resumen.transacciones.push(txHash);
      for (const p of pendientes) resumen.firmadas[p.esquema] = (resumen.firmadas[p.esquema] ?? 0) + 1;
    } catch (e) {
      resumen.error = (e as Error).message;
      await cola.fallo(pendientes, resumen.error.slice(0, 500));
      break;
    }
  }
  return resumen;
}

/**
 * Pedido de multiAttest: agrupa por esquema (en el orden en que aparece cada
 * uno). EAS emite un Attested por attestation en ese mismo orden; [orden]
 * dice a qué solicitud original corresponde cada evento.
 */
export function agruparPorEsquema(solicitudes: Solicitud[]) {
  const grupos = new Map<NombreEsquema, number[]>();
  solicitudes.forEach((s, i) => grupos.set(s.esquema, [...(grupos.get(s.esquema) ?? []), i]));
  const orden = [...grupos.values()].flat();
  const pedido = [...grupos.entries()].map(([nombre, indices]) => {
    const e = esquema(nombre);
    return {
      schema: schemaUid(e.schema, e.revocable),
      data: indices.map((i) => ({
        recipient: zeroAddress,
        expirationTime: 0n,
        revocable: e.revocable,
        refUID: solicitudes[i].refUID,
        data: solicitudes[i].data,
        value: 0n,
      })),
    };
  });
  return { pedido, orden };
}

const easAbi = parseAbi([
  "struct AttestationRequestData { address recipient; uint64 expirationTime; bool revocable; bytes32 refUID; bytes data; uint256 value; }",
  "struct MultiAttestationRequest { bytes32 schema; AttestationRequestData[] data; }",
  "function multiAttest(MultiAttestationRequest[] multiRequests) payable returns (bytes32[])",
  "event Attested(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schemaUID)",
  "error NotFound()",
  "error InvalidSchema()",
]);

/**
 * El RPC público reparte las peticiones entre nodos: justo después de
 * confirmarse una ola, un nodo atrasado todavía no ve sus attestations y la
 * siguiente ola, que apunta a ellas (refUID), falla con NotFound. Se espera
 * y se reintenta; cualquier otro error sale de inmediato.
 */
export async function reintentarSiNoExiste<T>(enviar: () => Promise<T>, intentos = 5, esperaMs = 3000): Promise<T> {
  for (let i = 1; ; i++) {
    try {
      return await enviar();
    } catch (e) {
      const noExiste = /NotFound|0xc5723b51/.test((e as Error).message);
      if (!noExiste || i >= intentos) throw e;
      await new Promise((r) => setTimeout(r, esperaMs));
    }
  }
}

/** EAS del OP Stack (predeploy) con una cuenta que firma (Cloud KMS). */
export class EasViem implements RedEAS {
  constructor(
    private readonly cuenta: LocalAccount,
    private readonly chain: Chain,
    rpcUrl?: string,
    readonly nombre = chain.id === 10 ? "optimism" : "optimism-sepolia",
  ) {
    const transport = http(rpcUrl);
    this.publico = createPublicClient({ chain, transport });
    this.billetera = createWalletClient({ chain, transport, account: cuenta });
  }

  private readonly publico;
  private readonly billetera;

  async atestar(solicitudes: Solicitud[]) {
    const { pedido, orden } = agruparPorEsquema(solicitudes);
    const txHash = await reintentarSiNoExiste(() =>
      this.billetera.writeContract({
        address: EAS_ADDRESS,
        abi: easAbi,
        functionName: "multiAttest",
        args: [pedido],
        chain: this.chain,
        account: this.cuenta,
      }),
    );
    const recibo = await this.publico.waitForTransactionReceipt({ hash: txHash });
    if (recibo.status !== "success") throw new Error(`La transacción ${txHash} falló`);
    const eventos = parseEventLogs({ abi: easAbi, logs: recibo.logs, eventName: "Attested" }).filter(
      (l) => l.address.toLowerCase() === EAS_ADDRESS.toLowerCase(),
    );
    const uids: Hex[] = new Array(solicitudes.length);
    eventos.forEach((ev, k) => (uids[orden[k]] = ev.args.uid));
    return { uids: uids.filter(Boolean), txHash };
  }
}

const segundos = (d: Date | string) => BigInt(Math.floor(new Date(d).getTime() / 1000));
const ESPERA = "(ap.ultimo_intento IS NULL OR ap.ultimo_intento < now() - interval '15 minutes')";

/**
 * Período de gracia: entregas y visitas se firman a los [DIAS_GRACIA] días
 * de llegar al servidor (cuando entran a la cola), para que el técnico
 * pueda corregir sus errores sin revocar nada. Si antes entran a un lote
 * (o, en las visitas, alguna entrega de su finca), se firman ya: el lote
 * las necesita firmadas. La firma lleva la fecha real de la entrega o visita.
 */
export const DIAS_GRACIA = 7;
const GRACIA_VENCIDA = `ap.creado_en < now() - interval '${DIAS_GRACIA} days'`;

/** Cola en Postgres: qué está listo para atestarse y dónde guardar los UIDs. */
export class ColaPg implements ColaAttestations {
  constructor(private readonly pool: pg.Pool) {}

  async listos(ola: Ola, limite: number): Promise<Pendiente[]> {
    if (ola === 1) return this.fincas(limite);
    if (ola === 2) return [...(await this.chequeos(limite)), ...(await this.verificaciones(limite)), ...(await this.entregas(limite))].slice(0, limite);
    if (ola === 3) return this.lotes(limite);
    return this.exportaciones(limite);
  }

  /** Versiones del lindero; la 2 espera a que la 1 esté firmada (refUID). */
  private async fincas(limite: number): Promise<Pendiente[]> {
    const { rows } = await this.pool.query(
      `SELECT ap.id AS "colaId", fv.finca_id AS "fincaId", fv.version, f.cultivo, fv.geo_hash AS "geoHash",
              ${AREA_OFICIAL("fv")}::float8 AS area, prev.attestation_uid AS ref,
              coalesce((SELECT array_agg(fo.sha256) FROM fotos fo
                        WHERE fo.entidad_tipo = 'finca' AND fo.entidad_id = f.id), '{}') AS fotos
       FROM attestations_pendientes ap
       JOIN fincas_versiones fv ON fv.finca_id = ap.entidad_id AND fv.version = ap.version
       JOIN fincas f ON f.id = fv.finca_id
       LEFT JOIN fincas_versiones prev ON prev.finca_id = fv.finca_id AND prev.version = fv.version - 1
       WHERE ap.esquema = 'Finca' AND (fv.version = 1 OR prev.attestation_uid IS NOT NULL) AND ${ESPERA}
       ORDER BY ap.id LIMIT $1`,
      [limite],
    );
    return rows.map((r) => ({
      esquema: "Finca",
      entidadId: r.fincaId,
      version: r.version,
      colaId: Number(r.colaId),
      solicitud: {
        esquema: "Finca",
        refUID: (r.ref ?? zeroHash) as Hex,
        data: codificar("Finca", [uuidABytes32(r.fincaId), r.version, r.cultivo, r.geoHash, Math.round(r.area * 100), hashDeHashes(r.fotos)]),
      },
    }));
  }

  private async chequeos(limite: number): Promise<Pendiente[]> {
    const { rows } = await this.pool.query(
      `SELECT c.id::text AS id, c.version_finca AS version, fv.attestation_uid AS ref, t.nombre AS temporada,
              c.resultado::text AS resultado, c.fuente, c.area_afectada_ha::float8 AS area, c.fecha
       FROM chequeos_deforestacion c
       JOIN fincas_versiones fv ON fv.finca_id = c.finca_id AND fv.version = c.version_finca
       LEFT JOIN temporadas t ON t.id = c.temporada_id
       WHERE c.attestation_uid IS NULL AND fv.attestation_uid IS NOT NULL
       ORDER BY c.id LIMIT $1`,
      [limite],
    );
    return rows.map((r) => ({
      esquema: "Chequeo",
      entidadId: r.id,
      version: r.version,
      colaId: null,
      solicitud: {
        esquema: "Chequeo",
        refUID: r.ref,
        data: codificar("Chequeo", [r.ref, r.temporada ?? "", r.resultado, r.fuente, Math.round(r.area * 10000), segundos(r.fecha)]),
      },
    }));
  }

  private async verificaciones(limite: number): Promise<Pendiente[]> {
    const { rows } = await this.pool.query(
      `SELECT ap.id AS "colaId", v.id, fv.attestation_uid AS ref, t.nombre AS temporada, v.fecha,
              v.lindero_cambio AS "linderoCambio",
              coalesce((SELECT array_agg(fo.sha256) FROM fotos fo
                        WHERE fo.entidad_tipo = 'verificacion' AND fo.entidad_id = v.id), '{}') AS fotos
       FROM attestations_pendientes ap
       JOIN verificaciones v ON v.id = ap.entidad_id
       JOIN fincas_versiones fv ON fv.finca_id = v.finca_id AND fv.version = v.version_finca
       LEFT JOIN temporadas t ON t.id = v.temporada_id
       WHERE ap.esquema = 'Verificacion' AND fv.attestation_uid IS NOT NULL AND ${ESPERA}
         AND (${GRACIA_VENCIDA} OR EXISTS (
               SELECT 1 FROM entregas e JOIN lote_entregas le ON le.entrega_id = e.id
               WHERE e.finca_id = v.finca_id AND e.anulada_en IS NULL))
       ORDER BY ap.id LIMIT $1`,
      [limite],
    );
    return rows.map((r) => ({
      esquema: "Verificacion",
      entidadId: r.id,
      version: 1,
      colaId: Number(r.colaId),
      solicitud: {
        esquema: "Verificacion",
        refUID: r.ref,
        data: codificar("Verificacion", [uuidABytes32(r.id), r.ref, r.temporada ?? "", segundos(r.fecha), r.linderoCambio, hashDeHashes(r.fotos)]),
      },
    }));
  }

  /** Apuntan a la versión vigente de su finca ya firmada; con período de gracia. */
  private async entregas(limite: number): Promise<Pendiente[]> {
    const { rows } = await this.pool.query(
      `SELECT ap.id AS "colaId", e.id, f.attestation_uid AS ref, f.cultivo, e.kg::float8 AS kg, e.fecha, e.estado
       FROM attestations_pendientes ap
       JOIN entregas e ON e.id = ap.entidad_id
       JOIN fincas f ON f.id = e.finca_id
       WHERE ap.esquema = 'Entrega' AND f.attestation_uid IS NOT NULL AND ${ESPERA}
         AND (${GRACIA_VENCIDA} OR EXISTS (SELECT 1 FROM lote_entregas le WHERE le.entrega_id = e.id))
       ORDER BY ap.id LIMIT $1`,
      [limite],
    );
    return rows.map((r) => ({
      esquema: "Entrega",
      entidadId: r.id,
      version: 1,
      colaId: Number(r.colaId),
      solicitud: {
        esquema: "Entrega",
        refUID: r.ref,
        data: codificar("Entrega", [uuidABytes32(r.id), r.ref, r.cultivo, kgX100(r.kg), segundos(r.fecha), r.estado]),
      },
    }));
  }

  /** Cuando todas sus entregas ya están firmadas. */
  private async lotes(limite: number): Promise<Pendiente[]> {
    const { rows } = await this.pool.query(
      `SELECT ap.id AS "colaId", l.id, l.cultivo, t.nombre AS temporada, l.kg::float8 AS kg, l.estado, l.beneficio, l.proceso,
              (SELECT array_agg(e.attestation_uid ORDER BY e.fecha, e.id)
               FROM lote_entregas le JOIN entregas e ON e.id = le.entrega_id WHERE le.lote_id = l.id) AS uids
       FROM attestations_pendientes ap
       JOIN lotes l ON l.id = ap.entidad_id
       JOIN temporadas t ON t.id = l.temporada_id
       WHERE ap.esquema = 'Lote' AND ${ESPERA}
         AND NOT EXISTS (SELECT 1 FROM lote_entregas le JOIN entregas e ON e.id = le.entrega_id
                         WHERE le.lote_id = l.id AND e.attestation_uid IS NULL)
       ORDER BY ap.id LIMIT $1`,
      [limite],
    );
    return rows.map((r) => ({
      esquema: "Lote",
      entidadId: r.id,
      version: 1,
      colaId: Number(r.colaId),
      solicitud: {
        esquema: "Lote",
        refUID: zeroHash,
        data: codificar("Lote", [uuidABytes32(r.id), r.cultivo, r.temporada, r.uids, kgX100(r.kg), r.estado, r.beneficio, r.proceso ?? ""]),
      },
    }));
  }

  /** Contenedores cerrados, con la referencia de la DDS y todos sus lotes firmados. */
  private async exportaciones(limite: number): Promise<Pendiente[]> {
    const { rows } = await this.pool.query(
      `SELECT ap.id AS "colaId", x.id, x.cultivo, x.contenedor, x.destino, x.dds_ref AS "ddsRef",
              (SELECT sum(l.kg)::float8 FROM exportacion_lotes el JOIN lotes l ON l.id = el.lote_id
               WHERE el.exportacion_id = x.id) AS kg,
              (SELECT array_agg(l.attestation_uid ORDER BY l.codigo) FROM exportacion_lotes el JOIN lotes l ON l.id = el.lote_id
               WHERE el.exportacion_id = x.id) AS uids
       FROM attestations_pendientes ap
       JOIN exportaciones x ON x.id = ap.entidad_id
       WHERE ap.esquema = 'Exportacion' AND x.estado = 'cerrada' AND x.dds_ref IS NOT NULL AND ${ESPERA}
         AND NOT EXISTS (SELECT 1 FROM exportacion_lotes el JOIN lotes l ON l.id = el.lote_id
                         WHERE el.exportacion_id = x.id AND l.attestation_uid IS NULL)
       ORDER BY ap.id LIMIT $1`,
      [limite],
    );
    return rows.map((r) => ({
      esquema: "Exportacion",
      entidadId: r.id,
      version: 1,
      colaId: Number(r.colaId),
      solicitud: {
        esquema: "Exportacion",
        refUID: zeroHash,
        data: codificar("Exportacion", [uuidABytes32(r.id), r.cultivo, r.uids, kgX100(r.kg), r.contenedor ?? "", r.destino, r.ddsRef]),
      },
    }));
  }

  async guardar(pendientes: Pendiente[], uids: Hex[], txHash: Hex, red: string): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      for (const [i, p] of pendientes.entries()) {
        const uid = uids[i];
        switch (p.esquema) {
          case "Finca":
            await client.query("UPDATE fincas_versiones SET attestation_uid = $3 WHERE finca_id = $1 AND version = $2", [p.entidadId, p.version, uid]);
            // La finca muestra la attestation de su lindero vigente.
            await client.query("UPDATE fincas SET attestation_uid = $3 WHERE id = $1 AND version_actual = $2", [p.entidadId, p.version, uid]);
            break;
          case "Chequeo":
            await client.query("UPDATE chequeos_deforestacion SET attestation_uid = $2 WHERE id = $1", [Number(p.entidadId), uid]);
            break;
          default: {
            const tabla = { Verificacion: "verificaciones", Entrega: "entregas", Lote: "lotes", Exportacion: "exportaciones" }[p.esquema];
            await client.query(`UPDATE ${tabla} SET attestation_uid = $2 WHERE id = $1`, [p.entidadId, uid]);
            // El contenedor cobrado lleva su attestation, para revisarlo en el verificador.
            if (p.esquema === "Exportacion") {
              await client.query(
                "UPDATE consumos SET attestation_uid = $2 WHERE exportacion_id = $1 AND tipo = 'contenedor' AND attestation_uid IS NULL",
                [p.entidadId, uid],
              );
            }
          }
        }
        if (p.colaId !== null) await client.query("DELETE FROM attestations_pendientes WHERE id = $1", [p.colaId]);
        await client.query(
          "INSERT INTO attestaciones (uid, esquema, entidad_id, version, red, tx_hash) VALUES ($1, $2, $3, $4, $5, $6)",
          [uid, p.esquema, p.entidadId, p.version, red, txHash],
        );
      }
      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async fallo(pendientes: Pendiente[], error: string): Promise<void> {
    const ids = pendientes.flatMap((p) => (p.colaId === null ? [] : [p.colaId]));
    if (ids.length === 0) return;
    await this.pool.query(
      "UPDATE attestations_pendientes SET intentos = intentos + 1, error = $2, ultimo_intento = now() WHERE id = ANY($1::bigint[])",
      [ids, error],
    );
  }
}
