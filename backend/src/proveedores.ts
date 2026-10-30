import { cultivo as cultivoDe } from "@trazacafe/eudr-eas-schemas";
import type pg from "pg";
import { z } from "zod";
import type { UsuarioActivo } from "./auth.ts";
import type { Resultado } from "./correcciones.ts";
import type { Aviso } from "./lotes.ts";
import { ALIAS_FINCA, AREA_OFICIAL, NOMBRES_VISIBLES } from "./repo.ts";

/**
 * Red de proveedores (Fase 2b): la exportadora invita a las cooperativas que
 * le venden, la cooperativa le vende lotes y la exportadora los recibe y los
 * pone en sus contenedores. La exportadora solo ve lo de los lotes que le
 * vendieron y nunca corrige datos de la cooperativa: deja observaciones.
 */

/** Tipos de organización que compran lotes a otras (invitan proveedores). */
export const TIPOS_CLIENTE = ["exportadora", "beneficio"];
export const puedeTenerProveedores = (tipo: string) => TIPOS_CLIENTE.includes(tipo);

/** Día de hoy en Nicaragua (UTC-6), más [dias]. */
const diaNicaragua = (dias = 0) => new Date(Date.now() - 6 * 3600_000 + dias * 86_400_000).toISOString().slice(0, 10);

/** Un día (AAAA-MM-DD) que no esté en el futuro (con un día de margen). */
const diaPasado = (que: string) =>
  z.iso.date().refine((d) => d <= diaNicaragua(1), { message: `La fecha de ${que} no puede estar en el futuro` });

export const invitarProveedorSchema = z.object({ email: z.email().transform((e) => e.toLowerCase()) });
export const respuestaVinculoSchema = z.object({ comparteNombres: z.boolean() });
export const ventaSchema = z.object({
  vinculoId: z.uuid(),
  kg: z.number().positive().max(1_000_000),
  fecha: diaPasado("envío"),
});
export const recepcionSchema = z.object({
  kgRecibidos: z.number().positive().max(1_000_000),
  fecha: diaPasado("recepción"),
});
export const observacionSchema = z
  .object({
    fincaId: z.uuid().optional(),
    loteId: z.uuid().optional(),
    texto: z.string().trim().min(3, "Escribe la observación (al menos 3 letras)").max(1000),
  })
  .refine((x) => (x.fincaId === undefined) !== (x.loteId === undefined), { message: "Indica la finca o el lote" });
export const respuestaObservacionSchema = z.object({
  texto: z.string().trim().min(1, "Escribe la respuesta").max(1000),
});
export type Venta = z.infer<typeof ventaSchema>;
export type Recepcion = z.infer<typeof recepcionSchema>;
export type ObservacionNueva = z.infer<typeof observacionSchema>;

/** Lo que se revisa antes de vender un lote. */
export interface LoteParaVenta {
  cultivo: string;
  /** Código del contenedor en que ya va, o `null`. */
  contenedor: string | null;
  /** A quién se vendió, o `null`. */
  vendidoA: string | null;
}

/** Por qué el lote no se puede vender a ese cliente, o `null`. */
export function motivoNoVenta(
  l: LoteParaVenta,
  vinculo: { estado: string; cliente: string; cultivos: string[] } | null,
): string | null {
  if (l.contenedor) return `El lote va en el contenedor ${l.contenedor}; no se puede vender`;
  if (l.vendidoA) return `El lote ya se vendió a ${l.vendidoA}`;
  if (!vinculo || vinculo.estado !== "activo") return "Esa organización no es un cliente activo";
  if (!vinculo.cultivos.includes(l.cultivo)) {
    return `${vinculo.cliente} no trabaja ${cultivoDe(l.cultivo)?.nombre.toLowerCase() ?? l.cultivo}`;
  }
  return null;
}

const kgTexto = (n: number) => n.toLocaleString("en-US", { maximumFractionDigits: 2 });

/** Aviso si la exportadora recibió otros kg que los enviados, o `null`. */
export function avisoDiferencia(kgEnviados: number, kgRecibidos: number | null): Aviso | null {
  if (kgRecibidos === null) return null;
  const diferencia = Math.round((kgRecibidos - kgEnviados) * 100) / 100;
  if (diferencia === 0) return null;
  const porcentaje = ((diferencia / kgEnviados) * 100).toFixed(1);
  return {
    codigo: "diferencia",
    mensaje:
      `Se recibieron ${kgTexto(kgRecibidos)} kg de ${kgTexto(kgEnviados)} enviados ` +
      `(${diferencia > 0 ? "+" : ""}${kgTexto(diferencia)} kg, ${diferencia > 0 ? "+" : ""}${porcentaje} %).`,
  };
}

export type EstadoVinculo = "pendiente" | "activo" | "rechazado" | "terminado";

export interface Vinculo {
  id: string;
  /** Papel de quien consulta: `cliente` si la otra organización le vende. */
  soy: "cliente" | "proveedora";
  /** La otra organización. */
  organizacion: { id: string; nombre: string };
  estado: EstadoVinculo;
  comparteNombres: boolean;
  invitadoEn: string;
  respondidoEn: string | null;
  terminadoEn: string | null;
  lotesEnviados: number;
  lotesRecibidos: number;
}

/** Venta de un lote, como la ven la cooperativa y la exportadora. */
export interface VentaLote {
  vinculoId: string;
  cliente: string;
  estado: "enviado" | "recibido";
  kgEnviados: number;
  fechaEnvio: string;
  kgRecibidos: number | null;
  fechaRecibido: string | null;
  /** Ya va en un contenedor de la exportadora: la venta no se deshace. */
  enContenedor: boolean;
}

export interface LotePorRecibir {
  id: string;
  codigo: string;
  cultivo: string;
  estado: string;
  temporadaNombre: string;
  proveedor: string;
  kgEnviados: number;
  fechaEnvio: string;
  attestationUid: string | null;
}

export interface FincaRevisada {
  id: string;
  /** Nombre, o alias ("Finca 3F2A") si la cooperativa no comparte nombres. */
  nombre: string;
  productorNombre: string | null;
  comunidad: string | null;
  cultivo: string;
  geometria: { type: string; coordinates: unknown };
  areaOficialHa: number;
  deforestacion: string;
  ultimoChequeo: string | null;
  /** Tiene visita de verificación en la temporada de alguno de sus lotes. */
  conVisita: boolean;
  ultimaVisita: string | null;
  attestationUid: string | null;
  /** Códigos de los lotes vendidos en que va. */
  lotes: string[];
}

export interface Revision {
  vinculo: Vinculo;
  lotes: {
    id: string;
    codigo: string;
    cultivo: string;
    temporadaNombre: string;
    estado: string;
    kgEnviados: number;
    kgRecibidos: number | null;
    venta: "enviado" | "recibido";
    avisos: Aviso[];
    attestationUid: string | null;
  }[];
  fincas: FincaRevisada[];
  resumen: { fincas: number; verdes: number; conVisita: number; areaOficialHa: number };
}

export interface Observacion {
  id: string;
  /** La hizo esta organización (exportadora) o se la hicieron (cooperativa). */
  hecha: boolean;
  cliente: string;
  proveedora: string;
  fincaId: string | null;
  fincaNombre: string | null;
  loteId: string | null;
  loteCodigo: string | null;
  texto: string;
  creadoEn: string;
  respuesta: string | null;
  respondidoEn: string | null;
}

/** Lo pendiente en la red, para los avisos de la pantalla de inicio. */
export interface AvisosRed {
  invitaciones: { id: string; organizacion: string }[];
  lotesPorRecibir: number;
  observacionesSinResponder: number;
}

export interface Proveedores {
  /** Vínculos en que participa la organización, como cliente o como proveedora. */
  vinculos(organizacionId: string): Promise<Vinculo[]>;
  /** La exportadora invita a la organización del administrador con ese correo. */
  invitar(u: UsuarioActivo, email: string): Promise<Resultado<Vinculo>>;
  /** La cooperativa acepta (eligiendo si comparte nombres) o rechaza. */
  responder(u: UsuarioActivo, id: string, aceptar: boolean, comparteNombres: boolean): Promise<Resultado<Vinculo>>;
  cambiarNombres(u: UsuarioActivo, id: string, comparteNombres: boolean): Promise<Resultado<Vinculo>>;
  /** Cualquiera de las dos termina el vínculo (o cancela la invitación). */
  terminar(u: UsuarioActivo, id: string): Promise<Resultado>;
  vender(u: UsuarioActivo, loteId: string, v: Venta): Promise<Resultado>;
  deshacerVenta(u: UsuarioActivo, loteId: string): Promise<Resultado>;
  porRecibir(organizacionId: string): Promise<LotePorRecibir[]>;
  recibir(u: UsuarioActivo, loteId: string, r: Recepcion): Promise<Resultado<{ aviso: Aviso | null }>>;
  revision(organizacionId: string, vinculoId: string): Promise<Resultado<Revision>>;
  observaciones(organizacionId: string): Promise<Observacion[]>;
  observar(u: UsuarioActivo, o: ObservacionNueva): Promise<Resultado<Observacion>>;
  responderObservacion(u: UsuarioActivo, id: string, texto: string): Promise<Resultado>;
  avisos(organizacionId: string): Promise<AvisosRed>;
}

const ok = <T>(valor: T): Resultado<T> => ({ ok: true, valor });
const no = (status: 403 | 404 | 409 | 422, mensaje: string): Resultado<never> => ({ ok: false, status, mensaje });
const iso = (d: Date | string | null) => (d ? new Date(d).toISOString() : null);

export class ProveedoresPg implements Proveedores {
  constructor(private readonly pool: pg.Pool) {}

  /** Corre [f] en una transacción; un Resultado de error deshace todo. */
  private async tx<T>(f: (c: pg.PoolClient) => Promise<Resultado<T>>): Promise<Resultado<T>> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const r = await f(client);
      await client.query(r.ok ? "COMMIT" : "ROLLBACK");
      return r;
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async vinculos(organizacionId: string): Promise<Vinculo[]> {
    const { rows } = await this.pool.query(
      `SELECT vi.id, CASE WHEN vi.cliente_id = $1 THEN 'cliente' ELSE 'proveedora' END AS soy,
              json_build_object('id', o.id, 'nombre', o.nombre) AS organizacion,
              vi.estado, vi.comparte_nombres AS "comparteNombres", vi.invitado_en AS "invitadoEn",
              vi.respondido_en AS "respondidoEn", vi.terminado_en AS "terminadoEn",
              (SELECT count(*) FROM ventas_lotes v WHERE v.vinculo_id = vi.id AND v.estado = 'enviado')::int AS "lotesEnviados",
              (SELECT count(*) FROM ventas_lotes v WHERE v.vinculo_id = vi.id AND v.estado = 'recibido')::int AS "lotesRecibidos"
       FROM vinculos vi
       JOIN organizaciones o ON o.id = CASE WHEN vi.cliente_id = $1 THEN vi.proveedora_id ELSE vi.cliente_id END
       WHERE vi.cliente_id = $1 OR vi.proveedora_id = $1
       ORDER BY vi.estado IN ('pendiente', 'activo') DESC, o.nombre, vi.invitado_en DESC`,
      [organizacionId],
    );
    return rows.map((r) => ({
      ...r,
      invitadoEn: iso(r.invitadoEn)!,
      respondidoEn: iso(r.respondidoEn),
      terminadoEn: iso(r.terminadoEn),
    }));
  }

  private async vinculo(organizacionId: string, id: string): Promise<Vinculo> {
    return (await this.vinculos(organizacionId)).find((v) => v.id === id)!;
  }

  async invitar(u: UsuarioActivo, email: string): Promise<Resultado<Vinculo>> {
    const id = crypto.randomUUID();
    const r = await this.tx(async (c) => {
      const { rows: [propia] } = await c.query<{ tipo: string }>("SELECT tipo FROM organizaciones WHERE id = $1", [
        u.organizacionId,
      ]);
      if (!propia || !puedeTenerProveedores(propia.tipo)) {
        return no(403, "Solo una exportadora o un beneficio invita proveedores.");
      }
      // Solo administradores que ya entraron a la app, de organizaciones vigentes.
      const { rows: [prov] } = await c.query<{ id: string }>(
        `SELECT o.id FROM invitaciones i JOIN organizaciones o ON o.id = i.organizacion_id
         WHERE i.email = $1 AND i.rol = 'admin' AND i.usuario_uid IS NOT NULL
           AND o.eliminada_en IS NULL AND o.eliminacion_programada IS NULL`,
        [email],
      );
      if (!prov) {
        return no(
          404,
          "Ese correo no es de un administrador activo en TrazaCafé. Pídele a la cooperativa el correo con que entra a la app.",
        );
      }
      if (prov.id === u.organizacionId) return no(422, "Ese correo es de tu propia organización.");
      const vigente = await c.query(
        "SELECT 1 FROM vinculos WHERE proveedora_id = $1 AND cliente_id = $2 AND estado IN ('pendiente', 'activo')",
        [prov.id, u.organizacionId],
      );
      if (vigente.rowCount) return no(409, "Ya hay una invitación o un vínculo con esa organización.");
      await c.query("INSERT INTO vinculos (id, proveedora_id, cliente_id, invitado_por) VALUES ($1, $2, $3, $4)", [
        id,
        prov.id,
        u.organizacionId,
        u.uid,
      ]);
      return ok(null);
    }).catch((e) => {
      // Dos invitaciones a la vez: la segunda choca con el índice único.
      if ((e as { constraint?: string }).constraint === "vinculos_vigente_unico") {
        return no(409, "Ya hay una invitación o un vínculo con esa organización.");
      }
      throw e;
    });
    return r.ok ? ok(await this.vinculo(u.organizacionId, id)) : r;
  }

  async responder(u: UsuarioActivo, id: string, aceptar: boolean, comparteNombres: boolean) {
    const { rowCount } = await this.pool.query(
      `UPDATE vinculos SET estado = $3, comparte_nombres = $4, respondido_por = $5, respondido_en = now()
       WHERE id = $1 AND proveedora_id = $2 AND estado = 'pendiente'`,
      [id, u.organizacionId, aceptar ? "activo" : "rechazado", aceptar && comparteNombres, u.uid],
    );
    if (!rowCount) return this.motivoSinCambio(u, id, "La invitación ya se respondió.");
    return ok(await this.vinculo(u.organizacionId, id));
  }

  async cambiarNombres(u: UsuarioActivo, id: string, comparteNombres: boolean) {
    const { rowCount } = await this.pool.query(
      "UPDATE vinculos SET comparte_nombres = $3 WHERE id = $1 AND proveedora_id = $2 AND estado = 'activo'",
      [id, u.organizacionId, comparteNombres],
    );
    if (!rowCount) return this.motivoSinCambio(u, id, "El vínculo no está activo.");
    return ok(await this.vinculo(u.organizacionId, id));
  }

  /** 404 si el vínculo no es de la organización como proveedora; si no, 409. */
  private async motivoSinCambio(u: UsuarioActivo, id: string, mensaje: string): Promise<Resultado<never>> {
    const existe = await this.pool.query("SELECT 1 FROM vinculos WHERE id = $1 AND proveedora_id = $2", [
      id,
      u.organizacionId,
    ]);
    return existe.rowCount ? no(409, mensaje) : no(404, "No encontrado.");
  }

  terminar(u: UsuarioActivo, id: string) {
    return this.tx(async (c) => {
      const { rows: [v] } = await c.query<{ estado: string }>(
        "SELECT estado FROM vinculos WHERE id = $1 AND (cliente_id = $2 OR proveedora_id = $2) FOR UPDATE",
        [id, u.organizacionId],
      );
      if (!v) return no(404, "No encontrado.");
      if (v.estado !== "pendiente" && v.estado !== "activo") return no(409, "El vínculo ya terminó.");
      await c.query(
        "UPDATE vinculos SET estado = 'terminado', terminado_por = $2, terminado_en = now() WHERE id = $1",
        [id, u.uid],
      );
      // Lo enviado y no recibido vuelve a la cooperativa; lo recibido se queda
      // con la exportadora (lo compró, y el EUDR obliga a conservarlo).
      await c.query("DELETE FROM ventas_lotes WHERE vinculo_id = $1 AND estado = 'enviado'", [id]);
      return ok(null);
    });
  }

  vender(u: UsuarioActivo, loteId: string, v: Venta) {
    return this.tx(async (c) => {
      const { rows: [l] } = await c.query<LoteParaVenta & { kg: number }>(
        `SELECT l.cultivo, l.kg::float8 AS kg,
                (SELECT x.codigo FROM exportacion_lotes el JOIN exportaciones x ON x.id = el.exportacion_id
                 WHERE el.lote_id = l.id) AS contenedor,
                (SELECT o.nombre FROM ventas_lotes vl JOIN organizaciones o ON o.id = vl.cliente_id
                 WHERE vl.lote_id = l.id) AS "vendidoA"
         FROM lotes l WHERE l.id = $1 AND l.organizacion_id = $2 FOR UPDATE`,
        [loteId, u.organizacionId],
      );
      if (!l) return no(404, "No encontrado.");
      const { rows: [vinculo] } = await c.query<{ estado: string; clienteId: string; cliente: string; cultivos: string[] }>(
        `SELECT vi.estado, vi.cliente_id AS "clienteId", o.nombre AS cliente, o.cultivos
         FROM vinculos vi JOIN organizaciones o ON o.id = vi.cliente_id
         WHERE vi.id = $1 AND vi.proveedora_id = $2`,
        [v.vinculoId, u.organizacionId],
      );
      const motivo = motivoNoVenta(l, vinculo ?? null);
      if (motivo) return no(409, `${motivo}.`);
      await c.query(
        `INSERT INTO ventas_lotes (lote_id, vinculo_id, cliente_id, kg_enviados, fecha_envio, vendido_por)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [loteId, v.vinculoId, vinculo.clienteId, v.kg, v.fecha, u.uid],
      );
      return ok(null);
    });
  }

  deshacerVenta(u: UsuarioActivo, loteId: string) {
    return this.tx(async (c) => {
      const { rows: [l] } = await c.query<{ vendido: boolean; contenedor: boolean }>(
        `SELECT EXISTS (SELECT 1 FROM ventas_lotes v WHERE v.lote_id = l.id) AS vendido,
                EXISTS (SELECT 1 FROM exportacion_lotes el WHERE el.lote_id = l.id) AS contenedor
         FROM lotes l WHERE l.id = $1 AND l.organizacion_id = $2 FOR UPDATE`,
        [loteId, u.organizacionId],
      );
      if (!l) return no(404, "No encontrado.");
      if (!l.vendido) return no(409, "El lote no está vendido.");
      if (l.contenedor) return no(409, "La exportadora ya puso el lote en un contenedor; la venta no se puede deshacer.");
      await c.query("DELETE FROM ventas_lotes WHERE lote_id = $1", [loteId]);
      return ok(null);
    });
  }

  async porRecibir(organizacionId: string): Promise<LotePorRecibir[]> {
    const { rows } = await this.pool.query(
      `SELECT l.id, l.codigo, l.cultivo, l.estado, t.nombre AS "temporadaNombre", o.nombre AS proveedor,
              v.kg_enviados::float8 AS "kgEnviados", to_char(v.fecha_envio, 'YYYY-MM-DD') AS "fechaEnvio",
              l.attestation_uid AS "attestationUid"
       FROM ventas_lotes v JOIN lotes l ON l.id = v.lote_id JOIN temporadas t ON t.id = l.temporada_id
       JOIN organizaciones o ON o.id = l.organizacion_id
       WHERE v.cliente_id = $1 AND v.estado = 'enviado'
       ORDER BY v.fecha_envio, l.codigo`,
      [organizacionId],
    );
    return rows;
  }

  recibir(u: UsuarioActivo, loteId: string, r: Recepcion) {
    return this.tx(async (c) => {
      const { rows: [v] } = await c.query<{ kgEnviados: number; contenedor: boolean }>(
        `SELECT v.kg_enviados::float8 AS "kgEnviados",
                EXISTS (SELECT 1 FROM exportacion_lotes el WHERE el.lote_id = v.lote_id) AS contenedor
         FROM ventas_lotes v WHERE v.lote_id = $1 AND v.cliente_id = $2 FOR UPDATE`,
        [loteId, u.organizacionId],
      );
      if (!v) return no(404, "Ese lote no te lo vendieron.");
      if (v.contenedor) return no(409, "El lote ya va en un contenedor; no se pueden cambiar los kg recibidos.");
      await c.query(
        `UPDATE ventas_lotes SET estado = 'recibido', kg_recibidos = $2, fecha_recibido = $3, recibido_por = $4
         WHERE lote_id = $1`,
        [loteId, r.kgRecibidos, r.fecha, u.uid],
      );
      return ok({ aviso: avisoDiferencia(v.kgEnviados, r.kgRecibidos) });
    });
  }

  async revision(organizacionId: string, vinculoId: string): Promise<Resultado<Revision>> {
    const vinculo = (await this.vinculos(organizacionId)).find((v) => v.id === vinculoId && v.soy === "cliente");
    if (!vinculo) return no(404, "No encontrado.");
    if (vinculo.estado !== "activo") return no(409, `El vínculo con ${vinculo.organizacion.nombre} no está activo.`);
    const proveedora = vinculo.organizacion.id;
    // Todos los lotes que esta proveedora le vendió al cliente (también en
    // vínculos anteriores), recibidos o por recibir.
    const { rows: lotes } = await this.pool.query(
      `SELECT l.id, l.codigo, l.cultivo, t.nombre AS "temporadaNombre", l.estado,
              v.kg_enviados::float8 AS "kgEnviados", v.kg_recibidos::float8 AS "kgRecibidos", v.estado AS venta,
              l.avisos, l.attestation_uid AS "attestationUid"
       FROM ventas_lotes v JOIN lotes l ON l.id = v.lote_id JOIN temporadas t ON t.id = l.temporada_id
       WHERE v.cliente_id = $1 AND l.organizacion_id = $2
       ORDER BY v.fecha_envio DESC, l.codigo`,
      [organizacionId, proveedora],
    );
    const { rows: fincas } = await this.pool.query(
      `WITH fl AS (
         SELECT DISTINCT e.finca_id, l.codigo, l.temporada_id
         FROM ventas_lotes v JOIN lotes l ON l.id = v.lote_id
         JOIN lote_entregas le ON le.lote_id = l.id JOIN entregas e ON e.id = le.entrega_id
         WHERE v.cliente_id = $1 AND l.organizacion_id = $2 AND e.anulada_en IS NULL)
       SELECT f.id, CASE WHEN $3 THEN f.nombre ELSE ${ALIAS_FINCA("f")} END AS nombre,
              CASE WHEN $3 THEN p.nombre END AS "productorNombre", p.comunidad, f.cultivo,
              ST_AsGeoJSON(f.geom, 7)::json AS geometria, ${AREA_OFICIAL("f")}::float8 AS "areaOficialHa",
              f.deforestacion,
              (SELECT max(c.fecha) FROM chequeos_deforestacion c WHERE c.finca_id = f.id) AS "ultimoChequeo",
              (SELECT max(vv.fecha) FROM verificaciones vv WHERE vv.finca_id = f.id AND vv.anulada_en IS NULL) AS "ultimaVisita",
              EXISTS (SELECT 1 FROM verificaciones vv JOIN fl x ON x.finca_id = vv.finca_id AND x.temporada_id = vv.temporada_id
                      WHERE vv.finca_id = f.id AND vv.anulada_en IS NULL) AS "conVisita",
              f.attestation_uid AS "attestationUid",
              (SELECT array_agg(DISTINCT x.codigo) FROM fl x WHERE x.finca_id = f.id) AS lotes
       FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE f.id IN (SELECT finca_id FROM fl)
       ORDER BY 2`,
      [organizacionId, proveedora, vinculo.comparteNombres],
    );
    const revisadas: FincaRevisada[] = fincas.map((f) => ({
      ...f,
      ultimoChequeo: iso(f.ultimoChequeo),
      ultimaVisita: iso(f.ultimaVisita),
    }));
    return ok({
      vinculo,
      lotes: lotes.map(({ avisos, ...l }) => {
        const diferencia = avisoDiferencia(l.kgEnviados, l.kgRecibidos);
        return { ...l, avisos: [...(avisos as Aviso[]), ...(diferencia ? [diferencia] : [])] };
      }),
      fincas: revisadas,
      resumen: {
        fincas: revisadas.length,
        verdes: revisadas.filter((f) => f.deforestacion === "verde").length,
        conVisita: revisadas.filter((f) => f.conVisita).length,
        areaOficialHa: Math.round(revisadas.reduce((s, f) => s + f.areaOficialHa, 0) * 100) / 100,
      },
    });
  }

  async observaciones(organizacionId: string): Promise<Observacion[]> {
    const { rows } = await this.pool.query(
      `SELECT ob.id, ob.cliente_id = $1 AS hecha, oc.nombre AS cliente, op.nombre AS proveedora,
              ob.finca_id AS "fincaId",
              CASE WHEN f.id IS NULL THEN NULL WHEN ${NOMBRES_VISIBLES("ob.proveedora_id", "$1")} THEN f.nombre
                   ELSE ${ALIAS_FINCA("f")} END AS "fincaNombre",
              ob.lote_id AS "loteId", l.codigo AS "loteCodigo", ob.texto, ob.creado_en AS "creadoEn",
              ob.respuesta, ob.respondido_en AS "respondidoEn"
       FROM observaciones ob
       JOIN organizaciones oc ON oc.id = ob.cliente_id JOIN organizaciones op ON op.id = ob.proveedora_id
       LEFT JOIN fincas f ON f.id = ob.finca_id LEFT JOIN lotes l ON l.id = ob.lote_id
       WHERE ob.cliente_id = $1 OR ob.proveedora_id = $1
       ORDER BY ob.respuesta IS NULL DESC, ob.creado_en DESC
       LIMIT 300`,
      [organizacionId],
    );
    return rows.map((r) => ({ ...r, creadoEn: iso(r.creadoEn)!, respondidoEn: iso(r.respondidoEn) }));
  }

  async observar(u: UsuarioActivo, o: ObservacionNueva): Promise<Resultado<Observacion>> {
    const id = crypto.randomUUID();
    const r = await this.tx(async (c) => {
      // La proveedora proveedora del lote (o de la finca) que le vendieron al cliente.
      const { rows: [proveedora] } = o.loteId
        ? await c.query<{ id: string }>(
            `SELECT l.organizacion_id AS id FROM ventas_lotes v JOIN lotes l ON l.id = v.lote_id
             WHERE v.lote_id = $1 AND v.cliente_id = $2`,
            [o.loteId, u.organizacionId],
          )
        : await c.query<{ id: string }>(
            `SELECT DISTINCT l.organizacion_id AS id FROM ventas_lotes v JOIN lotes l ON l.id = v.lote_id
             JOIN lote_entregas le ON le.lote_id = l.id JOIN entregas e ON e.id = le.entrega_id
             WHERE e.finca_id = $1 AND v.cliente_id = $2`,
            [o.fincaId, u.organizacionId],
          );
      if (!proveedora) return no(404, o.loteId ? "Ese lote no te lo vendieron." : "Esa finca no está en lotes que te vendieron.");
      const activo = await c.query(
        "SELECT 1 FROM vinculos WHERE proveedora_id = $1 AND cliente_id = $2 AND estado = 'activo'",
        [proveedora.id, u.organizacionId],
      );
      if (!activo.rowCount) return no(409, "El vínculo con esa organización no está activo.");
      await c.query(
        `INSERT INTO observaciones (id, cliente_id, proveedora_id, finca_id, lote_id, texto, creado_por)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [id, u.organizacionId, proveedora.id, o.fincaId ?? null, o.loteId ?? null, o.texto, u.uid],
      );
      return ok(null);
    });
    return r.ok ? ok((await this.observaciones(u.organizacionId)).find((x) => x.id === id)!) : r;
  }

  async responderObservacion(u: UsuarioActivo, id: string, texto: string): Promise<Resultado> {
    const { rowCount } = await this.pool.query(
      `UPDATE observaciones SET respuesta = $3, respondido_por = $4, respondido_en = now()
       WHERE id = $1 AND proveedora_id = $2 AND respuesta IS NULL`,
      [id, u.organizacionId, texto, u.uid],
    );
    if (rowCount) return ok(null);
    const existe = await this.pool.query("SELECT 1 FROM observaciones WHERE id = $1 AND proveedora_id = $2", [
      id,
      u.organizacionId,
    ]);
    return existe.rowCount ? no(409, "La observación ya tiene respuesta.") : no(404, "No encontrado.");
  }

  async avisos(organizacionId: string): Promise<AvisosRed> {
    const { rows: [a] } = await this.pool.query<AvisosRed>(
      `SELECT (SELECT coalesce(json_agg(json_build_object('id', vi.id, 'organizacion', o.nombre) ORDER BY vi.invitado_en), '[]')
               FROM vinculos vi JOIN organizaciones o ON o.id = vi.cliente_id
               WHERE vi.proveedora_id = $1 AND vi.estado = 'pendiente') AS invitaciones,
              (SELECT count(*) FROM ventas_lotes WHERE cliente_id = $1 AND estado = 'enviado')::int AS "lotesPorRecibir",
              (SELECT count(*) FROM observaciones WHERE proveedora_id = $1 AND respuesta IS NULL)::int
                AS "observacionesSinResponder"`,
      [organizacionId],
    );
    return a;
  }
}
