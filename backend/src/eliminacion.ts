import type pg from "pg";
import { z } from "zod";
import type { Usuario, UsuarioActivo } from "./auth.ts";
import type { Resultado } from "./correcciones.ts";
import { borrarFincaEnTx } from "./repo.ts";
import { normalizarCedula } from "./sync.ts";

/**
 * Eliminación de datos (Ley 787 y requisito de Google Play):
 * - un productor la pide en la página web y la aprueba el administrador de
 *   su cooperativa (o el administrador la hace directo en la app);
 * - cada persona del equipo puede eliminar su propia cuenta;
 * - el administrador puede eliminar la organización completa, 30 días
 *   después de pedirlo.
 *
 * Lo que el EUDR obliga a guardar (art. 12: 5 años desde la exportación) no
 * se borra: se anonimiza (sin nombre, cédula, comunidad, notas ni fotos) y
 * la tarea diaria lo borra cuando vence `conservar_hasta`.
 */

export const RETENCION_EUDR_ANIOS = 5;
export const DIAS_GRACIA_ORGANIZACION = 30;
/** Solicitudes de productores sin respuesta después de esto: GoProduction avisa a la cooperativa. */
export const DIAS_SIN_RESPUESTA = 15;
export const NOMBRE_PRODUCTOR_ELIMINADO = "Productor eliminado";
export const NOMBRE_ORGANIZACION_ELIMINADA = "Organización eliminada";

const motivo = z.string().trim().min(3, "Escribe el motivo (al menos 3 letras)").max(300);

export const solicitudProductorSchema = z.object({
  /** `null` = el productor no sabe a qué cooperativa pertenece (la atiende GoProduction). */
  organizacionId: z.uuid().nullable(),
  nombre: z.string().trim().min(3, "Escribe tu nombre completo").max(120),
  cedula: z
    .string()
    .trim()
    .max(20)
    .nullish()
    .refine((c) => !c || normalizarCedula(c) !== null, "La cédula debe tener el formato 001-010190-0001A"),
  comunidad: z.string().trim().max(120).nullish(),
  contacto: z.string().trim().min(5, "Escribe un teléfono o correo para avisarte").max(120),
  mensaje: z.string().trim().max(1000).nullish(),
  /** Campo trampa: la página lo esconde; si viene lleno, lo envió un bot. */
  sitio: z.string().optional(),
});
export type SolicitudProductor = z.infer<typeof solicitudProductorSchema>;

export const aprobarSolicitudSchema = z.object({ productorId: z.uuid() });
export const rechazarSolicitudSchema = z.object({ motivo });
export const eliminarProductorSchema = z.object({ motivo: motivo.optional() });

/** "2026-10-21" + n años (el 29 de febrero pasa al 28). */
export function sumarAnios(fecha: string, n: number): string {
  const [a, m, d] = fecha.split("-").map(Number);
  const dia = Math.min(d, new Date(Date.UTC(a + n, m, 0)).getUTCDate());
  return `${a + n}-${String(m).padStart(2, "0")}-${String(dia).padStart(2, "0")}`;
}

export type DestinoFinca = { accion: "borrar" } | { accion: "anonimizar"; conservarHasta: string };

/**
 * Qué hacer con una finca del productor que se elimina:
 * - sin nada firmado ni en un lote: se borra completa;
 * - con entregas exportadas: se anonimiza y se guarda 5 años desde la última exportación;
 * - firmada o en un lote sin exportar: se anonimiza y se guarda 5 años desde hoy
 *   (el lote todavía puede ir en un contenedor).
 */
export function destinoFinca(f: { sellada: boolean; ultimaExportacion: string | null }, hoy: string): DestinoFinca {
  if (!f.sellada && !f.ultimaExportacion) return { accion: "borrar" };
  return { accion: "anonimizar", conservarHasta: sumarAnios(f.ultimaExportacion ?? hoy, RETENCION_EUDR_ANIOS) };
}

export interface ResumenEliminacion {
  /** `borrado`: no quedó nada. `anonimizado`: quedan fincas sin datos personales por el EUDR. */
  productor: "borrado" | "anonimizado";
  fincasBorradas: number;
  fincasConservadas: number;
  conservarHasta: string | null;
}

export interface SolicitudEliminacion {
  id: string;
  nombre: string;
  cedula: string | null;
  comunidad: string | null;
  contacto: string;
  mensaje: string | null;
  creadaEn: string;
}

export interface ResultadoTarea {
  /** Organizaciones eliminadas hoy y los uid de su equipo (para borrar sus cuentas de Firebase). */
  organizaciones: { id: string; usuarios: string[] }[];
  /** Fincas anonimizadas cuyo plazo de 5 años venció y se borraron. */
  fincasPurgadas: number;
  /** Solicitudes de productores con más de DIAS_SIN_RESPUESTA días sin respuesta. */
  solicitudesSinRespuesta: number;
}

export interface Eliminaciones {
  organizacionesPublicas(): Promise<{ id: string; nombre: string }[]>;
  /** `false` si la organización elegida no existe (o ya se eliminó). */
  crearSolicitud(s: SolicitudProductor): Promise<boolean>;
  solicitudesPendientes(organizacionId: string): Promise<SolicitudEliminacion[]>;
  contarPendientes(organizacionId: string): Promise<number>;
  aprobarSolicitud(u: UsuarioActivo, id: string, productorId: string): Promise<Resultado<ResumenEliminacion>>;
  rechazarSolicitud(u: UsuarioActivo, id: string, motivo: string): Promise<Resultado>;
  eliminarProductor(u: UsuarioActivo, productorId: string, motivo: string | null): Promise<Resultado<ResumenEliminacion>>;
  /** Quita a la persona de su organización; borrar la cuenta de Firebase lo hace la API después. */
  eliminarCuenta(u: Usuario): Promise<Resultado>;
  /** Devuelve la fecha (ISO) en que se ejecutará. */
  programarEliminacionOrganizacion(u: UsuarioActivo): Promise<Resultado<string>>;
  cancelarEliminacionOrganizacion(u: UsuarioActivo): Promise<Resultado>;
  tareaDiaria(): Promise<ResultadoTarea>;
  archivosPorBorrar(limite: number): Promise<string[]>;
  archivosBorrados(borrados: string[], fallidos: string[]): Promise<void>;
}

const ok = <T>(valor: T): Resultado<T> => ({ ok: true, valor });
const no = (status: 403 | 404 | 409 | 422, mensaje: string): Resultado<never> => ({ ok: false, status, mensaje });
const hoyEnNicaragua = () => new Date(Date.now() - 6 * 3600_000).toISOString().slice(0, 10);

/** Eliminaciones sobre Postgres; cada operación en su transacción. */
export class EliminacionesPg implements Eliminaciones {
  constructor(private readonly pool: pg.Pool) {}

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

  async organizacionesPublicas() {
    const { rows } = await this.pool.query<{ id: string; nombre: string }>(
      "SELECT id, nombre FROM organizaciones WHERE eliminada_en IS NULL ORDER BY nombre",
    );
    return rows;
  }

  async crearSolicitud(s: SolicitudProductor) {
    if (s.organizacionId) {
      const org = await this.pool.query("SELECT 1 FROM organizaciones WHERE id = $1 AND eliminada_en IS NULL", [s.organizacionId]);
      if (org.rowCount === 0) return false;
    }
    const datos = {
      nombre: s.nombre,
      cedula: s.cedula ? normalizarCedula(s.cedula) : null,
      comunidad: s.comunidad || null,
      contacto: s.contacto,
      mensaje: s.mensaje || null,
    };
    await this.pool.query("INSERT INTO solicitudes_eliminacion (id, organizacion_id, datos) VALUES ($1, $2, $3)", [
      crypto.randomUUID(),
      s.organizacionId,
      JSON.stringify(datos),
    ]);
    return true;
  }

  async solicitudesPendientes(organizacionId: string) {
    const { rows } = await this.pool.query(
      `SELECT id, datos, creada_en FROM solicitudes_eliminacion
       WHERE organizacion_id = $1 AND estado = 'pendiente' ORDER BY creada_en`,
      [organizacionId],
    );
    return rows.map((r) => ({
      id: r.id,
      nombre: r.datos.nombre,
      cedula: r.datos.cedula ?? null,
      comunidad: r.datos.comunidad ?? null,
      contacto: r.datos.contacto,
      mensaje: r.datos.mensaje ?? null,
      creadaEn: new Date(r.creada_en).toISOString(),
    }));
  }

  async contarPendientes(organizacionId: string) {
    const { rows } = await this.pool.query<{ n: number }>(
      "SELECT count(*)::int AS n FROM solicitudes_eliminacion WHERE organizacion_id = $1 AND estado = 'pendiente'",
      [organizacionId],
    );
    return rows[0].n;
  }

  /** Bloquea una solicitud pendiente de la organización. */
  private async solicitud(c: pg.PoolClient, u: UsuarioActivo, id: string) {
    const { rows } = await c.query(
      "SELECT estado FROM solicitudes_eliminacion WHERE id = $1 AND organizacion_id = $2 FOR UPDATE",
      [id, u.organizacionId],
    );
    if (rows.length === 0) return no(404, "No encontrada.");
    if (rows[0].estado !== "pendiente") return no(409, "Esta solicitud ya fue atendida.");
    return null;
  }

  aprobarSolicitud(u: UsuarioActivo, id: string, productorId: string) {
    return this.tx<ResumenEliminacion>(async (c) => {
      const error = await this.solicitud(c, u, id);
      if (error) return error;
      const r = await eliminarProductorEnTx(c, u.organizacionId, productorId, u.uid, "Solicitud del productor");
      if (!r) return no(404, "Ese productor no existe en la organización.");
      // Al cerrarse se borran los datos que escribió el productor (nombre, cédula, contacto).
      await c.query(
        `UPDATE solicitudes_eliminacion SET estado = 'ejecutada', datos = '{}', productor_id = $2,
                resuelta_por = $3, resuelta_en = now() WHERE id = $1`,
        [id, productorId, u.uid],
      );
      return ok(r);
    });
  }

  rechazarSolicitud(u: UsuarioActivo, id: string, motivoTexto: string) {
    return this.tx(async (c) => {
      const error = await this.solicitud(c, u, id);
      if (error) return error;
      await c.query(
        `UPDATE solicitudes_eliminacion SET estado = 'rechazada', datos = '{}', motivo_rechazo = $2,
                resuelta_por = $3, resuelta_en = now() WHERE id = $1`,
        [id, motivoTexto, u.uid],
      );
      return ok(null);
    });
  }

  eliminarProductor(u: UsuarioActivo, productorId: string, motivoTexto: string | null) {
    return this.tx<ResumenEliminacion>(async (c) => {
      const r = await eliminarProductorEnTx(c, u.organizacionId, productorId, u.uid, motivoTexto);
      return r ? ok(r) : no(404, "No encontrado.");
    });
  }

  eliminarCuenta(u: Usuario) {
    return this.tx(async (c) => {
      if (!u.organizacionId) return ok(null); // Sin organización: solo queda la cuenta de Firebase.
      const { rows } = await c.query(
        `SELECT i.rol, o.eliminacion_programada IS NOT NULL AS programada,
                (SELECT count(*)::int FROM invitaciones x
                 WHERE x.organizacion_id = i.organizacion_id AND x.rol = 'admin' AND x.usuario_uid IS NOT NULL) AS admins
         FROM invitaciones i JOIN organizaciones o ON o.id = i.organizacion_id
         WHERE i.organizacion_id = $1 AND i.usuario_uid = $2 FOR UPDATE OF i`,
        [u.organizacionId, u.uid],
      );
      const yo = rows[0];
      if (yo?.rol === "admin" && yo.admins <= 1 && !yo.programada) {
        return no(
          409,
          "Eres el único administrador: antes de eliminar tu cuenta, nombra a otro administrador en Equipo o elimina la organización.",
        );
      }
      await c.query("DELETE FROM invitaciones WHERE organizacion_id = $1 AND usuario_uid = $2", [u.organizacionId, u.uid]);
      return ok(null);
    });
  }

  programarEliminacionOrganizacion(u: UsuarioActivo) {
    return this.tx<string>(async (c) => {
      const { rows } = await c.query(
        `UPDATE organizaciones
         SET eliminacion_programada = coalesce(eliminacion_programada, now() + make_interval(days => $2))
         WHERE id = $1 AND eliminada_en IS NULL RETURNING eliminacion_programada`,
        [u.organizacionId, DIAS_GRACIA_ORGANIZACION],
      );
      if (rows.length === 0) return no(404, "No encontrada.");
      await historial(c, u.organizacionId, "organizacion", u.organizacionId, "eliminar", { programada: true }, null, u.uid);
      return ok(new Date(rows[0].eliminacion_programada).toISOString());
    });
  }

  cancelarEliminacionOrganizacion(u: UsuarioActivo) {
    return this.tx(async (c) => {
      const { rowCount } = await c.query(
        "UPDATE organizaciones SET eliminacion_programada = NULL WHERE id = $1 AND eliminada_en IS NULL AND eliminacion_programada IS NOT NULL",
        [u.organizacionId],
      );
      if (rowCount === 0) return no(409, "La organización no tiene una eliminación programada.");
      await historial(c, u.organizacionId, "organizacion", u.organizacionId, "eliminar", { cancelada: true }, null, u.uid);
      return ok(null);
    });
  }

  async tareaDiaria(): Promise<ResultadoTarea> {
    const organizaciones: ResultadoTarea["organizaciones"] = [];
    const vencidas = await this.pool.query<{ id: string }>(
      "SELECT id FROM organizaciones WHERE eliminacion_programada <= now() AND eliminada_en IS NULL",
    );
    for (const { id } of vencidas.rows) {
      const r = await this.tx(async (c) => ok(await eliminarOrganizacionEnTx(c, id)));
      if (r.ok) organizaciones.push({ id, usuarios: r.valor });
    }

    let fincasPurgadas = 0;
    const purgar = await this.pool.query<{ id: string; organizacion_id: string }>(
      `SELECT f.id, p.organizacion_id FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE f.conservar_hasta < $1::date`,
      [hoyEnNicaragua()],
    );
    for (const f of purgar.rows) {
      await this.tx(async (c) => ok(await purgarFincaEnTx(c, f.organizacion_id, f.id)));
      fincasPurgadas++;
    }

    const { rows } = await this.pool.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM solicitudes_eliminacion
       WHERE estado = 'pendiente' AND creada_en < now() - make_interval(days => $1)`,
      [DIAS_SIN_RESPUESTA],
    );
    return { organizaciones, fincasPurgadas, solicitudesSinRespuesta: rows[0].n };
  }

  async archivosPorBorrar(limite: number) {
    const { rows } = await this.pool.query<{ ruta: string }>(
      "SELECT ruta FROM archivos_por_borrar WHERE intentos < 10 ORDER BY creado_en LIMIT $1",
      [limite],
    );
    return rows.map((r) => r.ruta);
  }

  async archivosBorrados(borrados: string[], fallidos: string[]) {
    if (borrados.length) await this.pool.query("DELETE FROM archivos_por_borrar WHERE ruta = ANY($1)", [borrados]);
    if (fallidos.length) {
      await this.pool.query("UPDATE archivos_por_borrar SET intentos = intentos + 1 WHERE ruta = ANY($1)", [fallidos]);
    }
  }
}

function historial(
  c: pg.PoolClient,
  org: string,
  entidad: string,
  id: string,
  accion: "eliminar" | "anonimizar",
  despues: unknown,
  motivoTexto: string | null,
  uid: string,
) {
  return c.query(
    `INSERT INTO correcciones (organizacion_id, entidad, entidad_id, accion, antes, despues, motivo, usuario_uid)
     VALUES ($1, $2, $3, $4, '{}', $5, $6, $7)`,
    [org, entidad, id, accion, JSON.stringify(despues), motivoTexto, uid],
  );
}

async function encolarArchivos(c: pg.PoolClient, rutas: string[]) {
  if (rutas.length === 0) return;
  await c.query("INSERT INTO archivos_por_borrar (ruta) SELECT unnest($1::text[]) ON CONFLICT DO NOTHING", [rutas]);
}

/** Deja las fotos con su hash pero sin archivo; devuelve las rutas a borrar. */
async function quitarArchivos(c: pg.PoolClient, condicion: string, params: unknown[]): Promise<string[]> {
  const { rows } = await c.query<{ ruta: string }>(
    `UPDATE fotos fo SET storage_path = NULL, archivo_borrado_en = now()
     FROM (SELECT id, storage_path FROM fotos WHERE ${condicion} FOR UPDATE) viejo
     WHERE fo.id = viejo.id
     RETURNING viejo.storage_path AS ruta`,
    params,
  );
  return rows.flatMap((r) => (r.ruta ? [r.ruta] : []));
}

/**
 * Elimina o anonimiza a un productor y sus fincas (reglas en `destinoFinca`)
 * dentro de la transacción de [c]. `null` si no existe en la organización.
 */
export async function eliminarProductorEnTx(
  c: pg.PoolClient,
  org: string,
  productorId: string,
  uid: string,
  motivoTexto: string | null,
): Promise<ResumenEliminacion | null> {
  const p = await c.query("SELECT 1 FROM productores WHERE id = $1 AND organizacion_id = $2 FOR UPDATE", [productorId, org]);
  if (p.rowCount === 0) return null;

  const { rows: fincas } = await c.query<{ id: string; sellada: boolean; ultimaExportacion: string | null }>(
    `SELECT f.id,
            f.attestation_uid IS NOT NULL
              OR EXISTS (SELECT 1 FROM fincas_versiones fv WHERE fv.finca_id = f.id AND fv.attestation_uid IS NOT NULL)
              OR EXISTS (SELECT 1 FROM entregas e WHERE e.finca_id = f.id AND e.attestation_uid IS NOT NULL)
              OR EXISTS (SELECT 1 FROM verificaciones v WHERE v.finca_id = f.id AND v.attestation_uid IS NOT NULL)
              OR EXISTS (SELECT 1 FROM entregas e JOIN lote_entregas le ON le.entrega_id = e.id WHERE e.finca_id = f.id)
              AS sellada,
            (SELECT to_char(max(coalesce(x.fecha_embarque, x.creado_en::date)), 'YYYY-MM-DD')
             FROM entregas e JOIN lote_entregas le ON le.entrega_id = e.id
             JOIN exportacion_lotes el ON el.lote_id = le.lote_id JOIN exportaciones x ON x.id = el.exportacion_id
             WHERE e.finca_id = f.id) AS "ultimaExportacion"
     FROM fincas f WHERE f.productor_id = $1 FOR UPDATE OF f`,
    [productorId],
  );

  // Ids cuyo historial de correcciones puede tener datos personales (nombres, notas, motivos).
  const { rows: relacionados } = await c.query<{ id: string }>(
    `SELECT $1::uuid::text AS id
     UNION SELECT f.id::text FROM fincas f WHERE f.productor_id = $1::uuid
     UNION SELECT e.id::text FROM entregas e JOIN fincas f ON f.id = e.finca_id WHERE f.productor_id = $1::uuid
     UNION SELECT v.id::text FROM verificaciones v JOIN fincas f ON f.id = v.finca_id WHERE f.productor_id = $1::uuid
     UNION SELECT fo.id::text FROM fotos fo WHERE fo.organizacion_id = $2 AND (fo.entidad_id = $1::uuid
       OR fo.entidad_id IN (SELECT id FROM fincas WHERE productor_id = $1::uuid)
       OR fo.entidad_id IN (SELECT v.id FROM verificaciones v JOIN fincas f ON f.id = v.finca_id WHERE f.productor_id = $1::uuid))`,
    [productorId, org],
  );

  const hoy = hoyEnNicaragua();
  const rutas: string[] = [];
  let borradas = 0;
  let conservarHasta: string | null = null;
  for (const f of fincas) {
    const destino = destinoFinca(f, hoy);
    if (destino.accion === "borrar") {
      rutas.push(...(await borrarFincaEnTx(c, org, f.id)));
      borradas++;
    } else {
      rutas.push(...(await anonimizarFincaEnTx(c, org, f.id, destino.conservarHasta)));
      if (!conservarHasta || destino.conservarHasta > conservarHasta) conservarHasta = destino.conservarHasta;
    }
  }

  await c.query(
    `UPDATE correcciones SET antes = '{}', despues = '{}', motivo = NULL
     WHERE organizacion_id = $1 AND entidad_id = ANY($2::text[])`,
    [org, relacionados.map((r) => r.id)],
  );

  const conservadas = fincas.length - borradas;
  if (conservadas === 0) {
    const fotos = await c.query<{ storage_path: string | null }>(
      "DELETE FROM fotos WHERE entidad_tipo = 'productor' AND entidad_id = $1 RETURNING storage_path",
      [productorId],
    );
    rutas.push(...fotos.rows.flatMap((x) => (x.storage_path ? [x.storage_path] : [])));
    await c.query("DELETE FROM productores WHERE id = $1", [productorId]);
    await c.query(
      "INSERT INTO eliminados (id, entidad, organizacion_id) VALUES ($1, 'productor', $2) ON CONFLICT (id) DO NOTHING",
      [productorId, org],
    );
  } else {
    rutas.push(...(await quitarArchivos(c, "entidad_tipo = 'productor' AND entidad_id = $1", [productorId])));
    await c.query(
      `UPDATE productores SET nombre = $2, cedula = NULL, comunidad = NULL, anonimizado_en = now(),
              conservar_hasta = greatest(conservar_hasta, $3::date)
       WHERE id = $1`,
      [productorId, NOMBRE_PRODUCTOR_ELIMINADO, conservarHasta],
    );
  }
  await encolarArchivos(c, rutas);

  const resumen: ResumenEliminacion = {
    productor: conservadas === 0 ? "borrado" : "anonimizado",
    fincasBorradas: borradas,
    fincasConservadas: conservadas,
    conservarHasta,
  };
  await historial(c, org, "productor", productorId, conservadas === 0 ? "eliminar" : "anonimizar", resumen, motivoTexto, uid);
  return resumen;
}

/**
 * Deja una finca sellada sin datos personales: borra lo que no está firmado
 * ni en un lote, quita notas y archivos de fotos (quedan sus hashes) y le
 * cambia el nombre. Conserva polígono, área, cultivo, versiones, chequeos y
 * las entregas selladas. Devuelve las rutas de Storage a borrar.
 */
async function anonimizarFincaEnTx(c: pg.PoolClient, org: string, fincaId: string, conservarHasta: string): Promise<string[]> {
  const rutas: string[] = [];
  // Entregas sin firmar ni en un lote.
  await c.query(
    `DELETE FROM attestations_pendientes WHERE esquema = 'Entrega' AND entidad_id IN (
       SELECT id FROM entregas e WHERE e.finca_id = $1 AND e.attestation_uid IS NULL
         AND NOT EXISTS (SELECT 1 FROM lote_entregas le WHERE le.entrega_id = e.id))`,
    [fincaId],
  );
  await c.query(
    `DELETE FROM entregas e WHERE e.finca_id = $1 AND e.attestation_uid IS NULL
       AND NOT EXISTS (SELECT 1 FROM lote_entregas le WHERE le.entrega_id = e.id)`,
    [fincaId],
  );
  // Visitas sin firmar, con sus fotos.
  const visitas = await c.query<{ id: string }>(
    "SELECT id FROM verificaciones WHERE finca_id = $1 AND attestation_uid IS NULL",
    [fincaId],
  );
  const ids = visitas.rows.map((v) => v.id);
  if (ids.length) {
    const fotos = await c.query<{ storage_path: string | null }>(
      "DELETE FROM fotos WHERE entidad_tipo = 'verificacion' AND entidad_id = ANY($1::uuid[]) RETURNING storage_path",
      [ids],
    );
    rutas.push(...fotos.rows.flatMap((x) => (x.storage_path ? [x.storage_path] : [])));
    await c.query("DELETE FROM attestations_pendientes WHERE esquema = 'Verificacion' AND entidad_id = ANY($1::uuid[])", [ids]);
    await c.query("DELETE FROM verificaciones WHERE id = ANY($1::uuid[])", [ids]);
    await c.query(
      `INSERT INTO eliminados (id, entidad, organizacion_id) SELECT unnest($1::uuid[]), 'verificacion', $2::uuid
       ON CONFLICT (id) DO NOTHING`,
      [ids, org],
    );
  }
  await c.query("UPDATE verificaciones SET nota = NULL WHERE finca_id = $1", [fincaId]);
  rutas.push(
    ...(await quitarArchivos(
      c,
      `(entidad_tipo = 'finca' AND entidad_id = $1)
       OR (entidad_tipo = 'verificacion' AND entidad_id IN (SELECT id FROM verificaciones WHERE finca_id = $1))`,
      [fincaId],
    )),
  );
  await c.query(
    `UPDATE fincas SET nombre = 'Finca eliminada · ' || left(id::text, 4), anonimizada_en = coalesce(anonimizada_en, now()),
            conservar_hasta = greatest(conservar_hasta, $2::date)
     WHERE id = $1`,
    [fincaId, conservarHasta],
  );
  return rutas;
}

/** Borra una finca anonimizada cuyo plazo venció, y a su productor si ya no le quedan fincas. */
async function purgarFincaEnTx(c: pg.PoolClient, org: string, fincaId: string) {
  const { rows } = await c.query<{ productor_id: string }>("SELECT productor_id FROM fincas WHERE id = $1 FOR UPDATE", [fincaId]);
  if (rows.length === 0) return;
  const productorId = rows[0].productor_id;
  const rutas = await borrarFincaEnTx(c, org, fincaId);
  const quedan = await c.query("SELECT 1 FROM fincas WHERE productor_id = $1 LIMIT 1", [productorId]);
  if (quedan.rowCount === 0) {
    const fotos = await c.query<{ storage_path: string | null }>(
      "DELETE FROM fotos WHERE entidad_tipo = 'productor' AND entidad_id = $1 RETURNING storage_path",
      [productorId],
    );
    rutas.push(...fotos.rows.flatMap((x) => (x.storage_path ? [x.storage_path] : [])));
    await c.query("DELETE FROM productores WHERE id = $1", [productorId]);
    await c.query(
      "INSERT INTO eliminados (id, entidad, organizacion_id) VALUES ($1, 'productor', $2) ON CONFLICT (id) DO NOTHING",
      [productorId, org],
    );
  }
  await encolarArchivos(c, rutas);
  await limpiarVacios(c, org);
}

/** Lotes sin entregas, contenedores sin lotes y temporadas sin uso de una organización eliminada. */
async function limpiarVacios(c: pg.PoolClient, org: string) {
  const eliminada = await c.query("SELECT 1 FROM organizaciones WHERE id = $1 AND eliminada_en IS NOT NULL", [org]);
  if (eliminada.rowCount === 0) return;
  const lotes = `SELECT l.id FROM lotes l WHERE l.organizacion_id = $1
                 AND NOT EXISTS (SELECT 1 FROM lote_entregas le WHERE le.lote_id = l.id)`;
  await c.query(`DELETE FROM attestations_pendientes WHERE esquema = 'Lote' AND entidad_id IN (${lotes})`, [org]);
  await c.query(`DELETE FROM exportacion_lotes WHERE lote_id IN (${lotes})`, [org]);
  await c.query(`DELETE FROM lotes WHERE id IN (${lotes})`, [org]);
  const exportaciones = `SELECT x.id FROM exportaciones x WHERE x.organizacion_id = $1
                         AND NOT EXISTS (SELECT 1 FROM exportacion_lotes el WHERE el.exportacion_id = x.id)`;
  await c.query(`DELETE FROM attestations_pendientes WHERE esquema = 'Exportacion' AND entidad_id IN (${exportaciones})`, [org]);
  await c.query(`DELETE FROM exportaciones WHERE id IN (${exportaciones})`, [org]);
  await c.query(
    `DELETE FROM temporadas t WHERE t.organizacion_id = $1
       AND NOT EXISTS (SELECT 1 FROM entregas e WHERE e.temporada_id = t.id)
       AND NOT EXISTS (SELECT 1 FROM verificaciones v WHERE v.temporada_id = t.id)
       AND NOT EXISTS (SELECT 1 FROM chequeos_deforestacion ch WHERE ch.temporada_id = t.id)
       AND NOT EXISTS (SELECT 1 FROM lotes l WHERE l.temporada_id = t.id)`,
    [org],
  );
}

/**
 * Ejecuta la eliminación de una organización: elimina o anonimiza a cada
 * productor, borra equipo, historial, solicitudes y lo que quede vacío, y
 * deja la fila sin nombre (la referencian los datos que se conservan y los
 * ids eliminados). Devuelve los uid del equipo para borrar sus cuentas.
 */
async function eliminarOrganizacionEnTx(c: pg.PoolClient, org: string): Promise<string[]> {
  const { rows: equipo } = await c.query<{ uid: string }>(
    "SELECT usuario_uid AS uid FROM invitaciones WHERE organizacion_id = $1 AND usuario_uid IS NOT NULL",
    [org],
  );
  await c.query(
    `UPDATE organizaciones SET nombre = $2, eliminada_en = now(), eliminacion_programada = NULL WHERE id = $1`,
    [org, NOMBRE_ORGANIZACION_ELIMINADA],
  );
  const { rows: productores } = await c.query<{ id: string }>(
    "SELECT id FROM productores WHERE organizacion_id = $1 AND anonimizado_en IS NULL",
    [org],
  );
  for (const p of productores) {
    await eliminarProductorEnTx(c, org, p.id, "sistema", "Eliminación de la organización");
  }
  // Fotos que hayan quedado sueltas (sin productor, finca ni visita).
  const sueltas = await c.query<{ storage_path: string | null }>(
    `DELETE FROM fotos fo WHERE fo.organizacion_id = $1 AND fo.archivo_borrado_en IS NULL
       AND NOT EXISTS (SELECT 1 FROM productores p WHERE p.id = fo.entidad_id)
       AND NOT EXISTS (SELECT 1 FROM fincas f WHERE f.id = fo.entidad_id)
       AND NOT EXISTS (SELECT 1 FROM verificaciones v WHERE v.id = fo.entidad_id)
     RETURNING storage_path`,
    [org],
  );
  await encolarArchivos(c, sueltas.rows.flatMap((x) => (x.storage_path ? [x.storage_path] : [])));
  await c.query("DELETE FROM correcciones WHERE organizacion_id = $1", [org]);
  await c.query("DELETE FROM solicitudes_eliminacion WHERE organizacion_id = $1", [org]);
  await c.query("DELETE FROM invitaciones WHERE organizacion_id = $1", [org]);
  await limpiarVacios(c, org);
  return equipo.map((e) => e.uid);
}
