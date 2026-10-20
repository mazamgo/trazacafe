import { convertirKg, cultivo, estadoValido } from "@trazacafe/eudr-eas-schemas";
import type pg from "pg";
import type { Rol, UsuarioActivo } from "./auth.ts";
import type { CambiosExportacion, ExportacionNueva, LoteCandidato } from "./exportaciones.ts";
import { avisoSatelite, type Aviso, type EntregaCandidata, type LoteNuevo } from "./lotes.ts";
import type { LoteSync, TemporadaNueva } from "./sync.ts";

export class AccesoDenegado extends Error {}

/** Datos bien formados pero que no tienen sentido juntos (p. ej. cacao en uva). */
export class DatosInvalidos extends Error {}

/** La versión del lindero que llegó no sigue a la vigente (otro técnico se adelantó). */
export class VersionDesfasada extends Error {}

export interface Invitacion {
  email: string;
  organizacionId: string;
  rol: Rol;
  invitadoPor: string;
  usuarioUid: string | null;
  creadoEn: string;
  aceptadaEn: string | null;
}

export interface ResultadoEliminarFinca {
  /** `en_lote`: alguna de sus entregas ya está en un lote. */
  estado: "eliminada" | "no_encontrada" | "atestada" | "en_lote";
  archivos: string[];
}

export type ResultadoCambiarCultivo = "cambiado" | "no_encontrada" | "con_entregas" | "atestada";

/** Lote ya guardado, con sus entregas, para la pantalla Lotes. */
export interface Lote {
  id: string;
  codigo: string;
  cultivo: string;
  temporadaId: string;
  temporadaNombre: string;
  estado: string;
  kg: number;
  kgEsperados: number;
  beneficio: string;
  proceso: string | null;
  avisos: Aviso[];
  attestationUid: string | null;
  creadoEn: string;
  /** Código del contenedor en que va, o `null`. */
  exportacionCodigo: string | null;
  entregas: {
    id: string;
    fincaId: string;
    fincaNombre: string;
    productorNombre: string;
    kg: number;
    estado: string;
    fecha: string;
  }[];
}

export type DatosLote = LoteNuevo & { id: string; beneficio: string; kgEsperados: number; avisos: Aviso[] };

export type ResultadoGuardarLote = "creado" | "codigo_repetido" | "entrega_ocupada";
export type ResultadoEliminarLote = "eliminado" | "no_encontrado" | "atestado";

/** Contenedor de exportación con sus lotes y el resumen para el paquete EUDR. */
export interface Exportacion {
  id: string;
  codigo: string;
  cultivo: string;
  comprador: string;
  destino: string;
  contenedor: string | null;
  fechaEmbarque: string | null;
  ddsRef: string | null;
  estado: "abierta" | "cerrada";
  attestationUid: string | null;
  creadoEn: string;
  kg: number;
  lotes: { id: string; codigo: string; kg: number; estado: string; temporadaNombre: string }[];
  /** Fincas de origen de todas sus entregas. */
  resumen: { entregas: number; fincas: number; areaOficialHa: number; fincasSinVerde: number };
}

export type ResultadoGuardarExportacion = "creada" | "codigo_repetido" | "lote_ocupado";

/** Finca de origen de un contenedor, con lo que piden TRACES y el comprador. */
export interface FincaDePaquete {
  id: string;
  nombre: string;
  productorNombre: string;
  comunidad: string | null;
  /** GeoJSON del lindero vigente (punto si mide menos de 4 ha). */
  geometria: { type: string; coordinates: unknown };
  areaOficialHa: number;
  version: number;
  geoHash: string;
  deforestacion: EstadoDeforestacion;
  ultimoChequeo: string | null;
  ultimaVisita: string | null;
  attestationUid: string | null;
  /** Kg de sus entregas que van en este contenedor. */
  kgEntregados: number;
}

export interface Paquete {
  organizacion: string;
  exportacion: Exportacion;
  fincas: FincaDePaquete[];
}
export type ResultadoCambiarExportacion = "cambiada" | "no_encontrada" | "cerrada";

export interface Temporada {
  id: string;
  nombre: string;
  inicio: string;
  fin: string;
  /** `null` = aplica a todos los cultivos. */
  cultivo: string | null;
}

export interface Organizacion {
  id: string;
  nombre: string;
  tipo: string;
  cultivos: string[];
}

export type EstadoDeforestacion = "pendiente" | "verde" | "amarillo" | "rojo";

export interface DatosOrganizacion {
  organizacion: Organizacion;
  /** De la más reciente a la más antigua; las fechas son días en Nicaragua. */
  temporadas: Temporada[];
  productores: {
    id: string;
    nombre: string;
    cedula: string | null;
    comunidad: string | null;
    consentimientoFirmado: boolean;
  }[];
  fincas: {
    id: string;
    productorId: string;
    nombre: string;
    cultivo: string;
    coordenadas: [number, number][];
    areaHa: number;
    /** Área calculada por PostGIS sobre el elipsoide: la que va al paquete EUDR. */
    areaOficialHa: number;
    geoHash: string;
    version: number;
    deforestacion: EstadoDeforestacion;
    ultimoChequeo: string | null;
    attestationUid: string | null;
  }[];
  verificaciones: {
    id: string;
    fincaId: string;
    temporadaId: string | null;
    fecha: string;
    linderoCambio: boolean;
    versionFinca: number;
    nota: string | null;
  }[];
  entregas: {
    id: string;
    fincaId: string;
    temporadaId: string | null;
    kg: number;
    estado: string;
    fecha: string;
    attestationUid: string | null;
    /** Código del lote en que va (ya no se puede corregir), o `null`. */
    loteCodigo: string | null;
    /** Tiene correcciones en el historial. */
    corregida: boolean;
  }[];
}

/** Finca a revisar por satélite: su lindero vigente como GeoJSON. */
export interface FincaPorRevisar {
  fincaId: string;
  version: number;
  temporadaId: string | null;
  /** Polígono; si la finca es un punto, un círculo de su área declarada. */
  geometria: { type: "Polygon" | "MultiPolygon"; coordinates: unknown };
}

export interface Chequeo {
  fincaId: string;
  version: number;
  temporadaId: string | null;
  fuente: string;
  alertas: number;
  areaAfectadaHa: number;
  resultado: Exclude<EstadoDeforestacion, "pendiente">;
  detalle: unknown;
}

export interface Repo {
  /** Guarda (idempotente) lo que llega de la app y encola las attestations. */
  guardarSync(usuario: UsuarioActivo, datos: LoteSync): Promise<void>;

  buscarInvitacion(email: string): Promise<Invitacion | null>;
  /** Marca la invitación como aceptada por esa cuenta de Firebase. */
  aceptarInvitacion(email: string, uid: string): Promise<void>;
  /** `false` si el correo ya tiene una invitación (en cualquier organización). */
  crearInvitacion(inv: Pick<Invitacion, "email" | "organizacionId" | "rol" | "invitadoPor">): Promise<boolean>;
  listarInvitaciones(organizacionId: string): Promise<Invitacion[]>;
  /** Devuelve la invitación borrada, o `null` si no existía en esa organización. */
  eliminarInvitacion(organizacionId: string, email: string): Promise<Invitacion | null>;

  /**
   * Borra una finca de la organización si ni ella ni sus entregas se
   * atestaron, con sus versiones, visitas, chequeos, entregas, fotos y
   * attestations pendientes. Lo atestado no se borra: hay que revocar su
   * attestation (semana 4). Devuelve las rutas en Storage de las fotos.
   */
  eliminarFinca(organizacionId: string, fincaId: string): Promise<ResultadoEliminarFinca>;

  /**
   * Cambia el cultivo de una finca que todavía no tiene entregas ni está
   * atestada (las entregas usan los estados de su cultivo). Las visitas se
   * reasignan a la temporada que les toca con el cultivo nuevo.
   */
  cambiarCultivoFinca(organizacionId: string, fincaId: string, cultivo: string): Promise<ResultadoCambiarCultivo>;

  /**
   * Entregas de la organización con lo necesario para armar lotes: las de
   * [ids], o todas las de un cultivo y temporada.
   */
  entregasCandidatas(
    organizacionId: string,
    filtro: { ids: string[] } | { cultivo: string; temporadaId: string },
  ): Promise<EntregaCandidata[]>;
  /** Guarda el lote ya evaluado y encola su attestation. */
  guardarLote(organizacionId: string, uid: string, lote: DatosLote): Promise<ResultadoGuardarLote>;
  /** Del más reciente al más antiguo. */
  listarLotes(organizacionId: string): Promise<Lote[]>;
  /** Deshace un lote que todavía no está en la blockchain; sus entregas quedan libres. */
  eliminarLote(organizacionId: string, loteId: string): Promise<ResultadoEliminarLote>;

  /** Lotes de la organización con [ids], con el contenedor en que ya van. */
  lotesCandidatos(organizacionId: string, ids: string[]): Promise<LoteCandidato[]>;
  guardarExportacion(
    organizacionId: string,
    uid: string,
    x: ExportacionNueva & { id: string; cultivo: string },
  ): Promise<ResultadoGuardarExportacion>;
  /** Del más reciente al más antiguo. */
  listarExportaciones(organizacionId: string): Promise<Exportacion[]>;
  /** Solo mientras el contenedor está abierto. */
  actualizarExportacion(organizacionId: string, id: string, cambios: CambiosExportacion): Promise<ResultadoCambiarExportacion>;
  /** Deshace un contenedor abierto; sus lotes quedan libres. */
  eliminarExportacion(organizacionId: string, id: string): Promise<ResultadoCambiarExportacion>;
  /** Contenedor con sus fincas de origen, para el paquete EUDR; `null` si no es de la organización. */
  paqueteExportacion(organizacionId: string, id: string): Promise<Paquete | null>;
  /** Pasa un contenedor abierto a cerrado y encola su attestation. */
  cerrarExportacion(organizacionId: string, id: string): Promise<ResultadoCambiarExportacion>;

  /** Todo lo de la organización, para que cada celular vea lo del equipo. */
  datosOrganizacion(organizacionId: string): Promise<DatosOrganizacion>;

  /** Foto de la organización, o `null` si no existe o es de otra. */
  buscarFoto(organizacionId: string, fotoId: string): Promise<{ sha256: string; storagePath: string | null } | null>;
  marcarFotoSubida(fotoId: string, storagePath: string): Promise<void>;

  organizacion(organizacionId: string): Promise<Organizacion | null>;
  /**
   * Cambia los cultivos con que trabaja la organización. No quita un cultivo
   * que ya tiene fincas: en ese caso no cambia nada y devuelve esos cultivos.
   */
  actualizarCultivos(organizacionId: string, cultivos: string[]): Promise<string[]>;

  listarTemporadas(organizacionId: string): Promise<Temporada[]>;
  /**
   * Crea la temporada y le asigna las entregas y visitas que quedaron sin
   * temporada en esas fechas. `null` si se traslapa con otra.
   */
  crearTemporada(organizacionId: string, t: TemporadaNueva & { id: string }, uid: string): Promise<Temporada | null>;

  /** Fincas con temporada vigente sin chequeo de su lindero actual en esa temporada. */
  fincasPorRevisar(limite: number): Promise<FincaPorRevisar[]>;
  /** La finca de la organización para revisarla ahora, o `null` si no es suya. */
  fincaParaRevisar(organizacionId: string, fincaId: string): Promise<FincaPorRevisar | null>;
  guardarChequeo(c: Chequeo): Promise<void>;
}

const COLUMNAS_INVITACION = `email, organizacion_id AS "organizacionId", rol, invitado_por AS "invitadoPor",
  usuario_uid AS "usuarioUid", creado_en AS "creadoEn", aceptada_en AS "aceptadaEn"`;

/**
 * Temporada de la organización que contiene un instante, para el cultivo de
 * la finca: primero la temporada de ese cultivo y, si no hay, la de todos.
 * Las fechas de temporada son días de calendario en Nicaragua, no en UTC.
 */
/**
 * Área oficial de una finca [t] (fincas o fincas_versiones). En un polígono
 * la calcula PostGIS; un punto no tiene área, así que se usa la declarada
 * (fincas de menos de 4 ha). Es la que va al paquete EUDR (TRACES pide el
 * área de las fincas de un punto).
 */
export const AREA_OFICIAL = (t: string) =>
  `(CASE WHEN GeometryType(${t}.geom) = 'POINT' THEN ${t}.area_ha ELSE ${t}.area_oficial_ha END)`;

export const TEMPORADA_DE = (org: string, fecha: string, finca: string) =>
  `(SELECT t.id FROM temporadas t, fincas fx
     WHERE fx.id = ${finca} AND t.organizacion_id = ${org}
       AND (t.cultivo IS NULL OR t.cultivo = fx.cultivo)
       AND (${fecha}::timestamptz AT TIME ZONE 'America/Managua')::date BETWEEN t.inicio AND t.fin
     ORDER BY t.cultivo IS NULL LIMIT 1)`;

/** Igual que TEMPORADA_DE pero para hoy y una finca `f` ya presente en la consulta. */
const TEMPORADA_ACTUAL_DE_F = `(SELECT t.id FROM temporadas t
     WHERE t.organizacion_id = p.organizacion_id
       AND (t.cultivo IS NULL OR t.cultivo = f.cultivo)
       AND (now() AT TIME ZONE 'America/Managua')::date BETWEEN t.inicio AND t.fin
     ORDER BY t.cultivo IS NULL LIMIT 1)`;

/** Geometría para el satélite: los puntos se vuelven un círculo de su área. */
const GEOMETRIA_SATELITE = `ST_AsGeoJSON(CASE WHEN GeometryType(f.geom) = 'POINT'
    THEN ST_Buffer(f.geom::geography, sqrt(f.area_ha * 10000 / pi()))::geometry
    ELSE f.geom END, 7)::json`;

export class PgRepo implements Repo {
  constructor(private readonly pool: pg.Pool) {}

  async guardarSync(
    usuario: UsuarioActivo,
    { productores, fincas, versionesFinca, verificaciones, entregas, fotos }: LoteSync,
  ): Promise<void> {
    const org = usuario.organizacionId;
    const client = await this.pool.connect();
    const fincaDeLaOrganizacion = async (fincaId: string) => {
      const r = await client.query<{ version_actual: number; cultivo: string }>(
        `SELECT f.version_actual, f.cultivo FROM fincas f JOIN productores p ON p.id = f.productor_id
         WHERE f.id = $1 AND p.organizacion_id = $2`,
        [fincaId, org],
      );
      if (r.rowCount === 0) throw new AccesoDenegado(`Finca ${fincaId} no pertenece a la organización`);
      return { version: r.rows[0].version_actual, cultivo: r.rows[0].cultivo };
    };

    try {
      await client.query("BEGIN");
      const cultivosOrg = new Set(
        (await client.query<{ cultivos: string[] }>("SELECT cultivos FROM organizaciones WHERE id = $1", [org])).rows[0]
          ?.cultivos ?? [],
      );
      for (const p of productores) {
        await client.query(
          `INSERT INTO productores (id, organizacion_id, nombre, cedula, comunidad, consentimiento_firmado, creado_por)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, cedula = EXCLUDED.cedula,
             comunidad = EXCLUDED.comunidad
           WHERE productores.organizacion_id = EXCLUDED.organizacion_id`,
          [p.id, org, p.nombre, p.cedula ?? null, p.comunidad ?? null, p.consentimientoFirmado, usuario.uid],
        );
      }

      for (const f of fincas) {
        const propio = await client.query("SELECT 1 FROM productores WHERE id = $1 AND organizacion_id = $2", [
          f.productorId,
          org,
        ]);
        if (propio.rowCount === 0) throw new AccesoDenegado(`Productor ${f.productorId} no pertenece a la organización`);
        if (!cultivosOrg.has(f.cultivo)) {
          throw new DatosInvalidos(
            `La organización no trabaja ${cultivo(f.cultivo)?.nombre ?? f.cultivo}; actívalo en la app (menú ⋮ → Cultivos).`,
          );
        }

        // Una finca ya registrada no se modifica; un lindero nuevo llega como versión.
        const nueva = await client.query(
          `INSERT INTO fincas (id, productor_id, nombre, cultivo, geom, area_ha, geo_hash, creado_por)
           VALUES ($1, $2, $3, $4, ST_SetSRID(ST_GeomFromGeoJSON($5), 4326), $6, $7, $8)
           ON CONFLICT (id) DO NOTHING`,
          [f.id, f.productorId, f.nombre, f.cultivo, JSON.stringify(aGeometria(f.coordenadas)), f.areaHa, f.geoHash, usuario.uid],
        );
        if (nueva.rowCount === 1) {
          await client.query(
            `INSERT INTO fincas_versiones (finca_id, version, geom, area_ha, geo_hash, creado_por)
             SELECT id, 1, geom, area_ha, geo_hash, creado_por FROM fincas WHERE id = $1`,
            [f.id],
          );
        }
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id, version) VALUES ('Finca', $1, 1)
           ON CONFLICT DO NOTHING`,
          [f.id],
        );
      }

      for (const v of versionesFinca) {
        const { version: actual } = await fincaDeLaOrganizacion(v.fincaId);
        if (v.version <= actual) {
          // Ya recibida (reintento de sincronización): solo se acepta si es la misma.
          const igual = await client.query(
            "SELECT 1 FROM fincas_versiones WHERE finca_id = $1 AND version = $2 AND geo_hash = $3",
            [v.fincaId, v.version, v.geoHash],
          );
          if (igual.rowCount === 1) continue;
          throw new VersionDesfasada(
            `La finca ya tiene una versión ${v.version} distinta; sincroniza para ver el lindero vigente.`,
          );
        }
        if (v.version !== actual + 1) {
          throw new VersionDesfasada(`Falta la versión ${actual + 1} del lindero antes de la ${v.version}.`);
        }
        const geom = JSON.stringify(aGeometria(v.coordenadas));
        await client.query(
          `INSERT INTO fincas_versiones (finca_id, version, geom, area_ha, geo_hash, creado_por)
           VALUES ($1, $2, ST_SetSRID(ST_GeomFromGeoJSON($3), 4326), $4, $5, $6)`,
          [v.fincaId, v.version, geom, v.areaHa, v.geoHash, usuario.uid],
        );
        await client.query(
          `UPDATE fincas SET geom = ST_SetSRID(ST_GeomFromGeoJSON($2), 4326), area_ha = $3, geo_hash = $4,
             version_actual = $5, deforestacion = 'pendiente', attestation_uid = NULL
           WHERE id = $1`,
          [v.fincaId, geom, v.areaHa, v.geoHash, v.version],
        );
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id, version) VALUES ('Finca', $1, $2)
           ON CONFLICT DO NOTHING`,
          [v.fincaId, v.version],
        );
      }

      for (const v of verificaciones) {
        await fincaDeLaOrganizacion(v.fincaId);
        await client.query(
          `INSERT INTO verificaciones (id, finca_id, temporada_id, fecha, lindero_cambio, version_finca, nota, creado_por)
           VALUES ($1, $2, ${TEMPORADA_DE("$3", "$4", "$2")}, $4, $5, $6, $7, $8)
           ON CONFLICT (id) DO NOTHING`,
          [v.id, v.fincaId, org, v.fecha, v.linderoCambio, v.versionFinca, v.nota ?? null, usuario.uid],
        );
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Verificacion', $1)
           ON CONFLICT DO NOTHING`,
          [v.id],
        );
      }

      for (const e of entregas) {
        const finca = await fincaDeLaOrganizacion(e.fincaId);
        if (!estadoValido(finca.cultivo, e.estado)) {
          const c = cultivo(finca.cultivo);
          throw new DatosInvalidos(
            `"${e.estado}" no es un estado de ${c?.nombre ?? finca.cultivo}; ` +
              `use ${c?.estados.map((x) => x.id).join(", ") ?? "otro estado"}.`,
          );
        }
        // Como las fincas, una entrega no se modifica después de recibida.
        await client.query(
          `INSERT INTO entregas (id, finca_id, temporada_id, kg, estado, fecha, creado_por)
           VALUES ($1, $2, ${TEMPORADA_DE("$3", "$6", "$2")}, $4, $5, $6, $7)
           ON CONFLICT (id) DO NOTHING`,
          [e.id, e.fincaId, org, e.kg, e.estado, e.fecha, usuario.uid],
        );
        await client.query(
          `INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Entrega', $1)
           ON CONFLICT DO NOTHING`,
          [e.id],
        );
      }

      for (const foto of fotos) {
        const consulta = {
          productor: "SELECT 1 FROM productores WHERE id = $1 AND organizacion_id = $2",
          finca: `SELECT 1 FROM fincas f JOIN productores p ON p.id = f.productor_id
                  WHERE f.id = $1 AND p.organizacion_id = $2`,
          verificacion: `SELECT 1 FROM verificaciones v JOIN fincas f ON f.id = v.finca_id
                         JOIN productores p ON p.id = f.productor_id
                         WHERE v.id = $1 AND p.organizacion_id = $2`,
        }[foto.entidadTipo];
        const propia = await client.query(consulta, [foto.entidadId, org]);
        if (propia.rowCount === 0) {
          throw new AccesoDenegado(`${foto.entidadTipo} ${foto.entidadId} no pertenece a la organización`);
        }
        await client.query(
          `INSERT INTO fotos (id, organizacion_id, entidad_tipo, entidad_id, tipo, sha256, creado_por)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           ON CONFLICT (id) DO NOTHING`,
          [foto.id, org, foto.entidadTipo, foto.entidadId, foto.tipo, foto.sha256, usuario.uid],
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

  async buscarInvitacion(email: string): Promise<Invitacion | null> {
    const { rows } = await this.pool.query<Invitacion>(
      `SELECT ${COLUMNAS_INVITACION} FROM invitaciones WHERE email = $1`,
      [email.toLowerCase()],
    );
    return rows[0] ?? null;
  }

  async aceptarInvitacion(email: string, uid: string): Promise<void> {
    await this.pool.query(
      `UPDATE invitaciones SET usuario_uid = $2, aceptada_en = COALESCE(aceptada_en, now())
       WHERE email = $1`,
      [email.toLowerCase(), uid],
    );
  }

  async crearInvitacion(inv: Pick<Invitacion, "email" | "organizacionId" | "rol" | "invitadoPor">): Promise<boolean> {
    const r = await this.pool.query(
      `INSERT INTO invitaciones (email, organizacion_id, rol, invitado_por) VALUES ($1, $2, $3, $4)
       ON CONFLICT (email) DO NOTHING`,
      [inv.email.toLowerCase(), inv.organizacionId, inv.rol, inv.invitadoPor],
    );
    return r.rowCount === 1;
  }

  async listarInvitaciones(organizacionId: string): Promise<Invitacion[]> {
    const { rows } = await this.pool.query<Invitacion>(
      `SELECT ${COLUMNAS_INVITACION} FROM invitaciones WHERE organizacion_id = $1 ORDER BY rol, email`,
      [organizacionId],
    );
    return rows;
  }

  async eliminarInvitacion(organizacionId: string, email: string): Promise<Invitacion | null> {
    const { rows } = await this.pool.query<Invitacion>(
      `DELETE FROM invitaciones WHERE organizacion_id = $1 AND email = $2 RETURNING ${COLUMNAS_INVITACION}`,
      [organizacionId, email.toLowerCase()],
    );
    return rows[0] ?? null;
  }

  async eliminarFinca(organizacionId: string, fincaId: string): Promise<ResultadoEliminarFinca> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const { rows } = await client.query<{ atestada: boolean; en_lote: boolean }>(
        `SELECT EXISTS (SELECT 1 FROM fincas_versiones fv WHERE fv.finca_id = f.id AND fv.attestation_uid IS NOT NULL)
                OR f.attestation_uid IS NOT NULL
                OR EXISTS (SELECT 1 FROM entregas e WHERE e.finca_id = f.id AND e.attestation_uid IS NOT NULL)
                OR EXISTS (SELECT 1 FROM verificaciones v WHERE v.finca_id = f.id AND v.attestation_uid IS NOT NULL)
                AS atestada,
                EXISTS (SELECT 1 FROM entregas e JOIN lote_entregas le ON le.entrega_id = e.id WHERE e.finca_id = f.id)
                AS en_lote
         FROM fincas f JOIN productores p ON p.id = f.productor_id
         WHERE f.id = $1 AND p.organizacion_id = $2 FOR UPDATE OF f`,
        [fincaId, organizacionId],
      );
      if (rows.length === 0 || rows[0].atestada || rows[0].en_lote) {
        await client.query("ROLLBACK");
        const estado = rows.length === 0 ? "no_encontrada" : rows[0].atestada ? "atestada" : "en_lote";
        return { estado, archivos: [] };
      }
      await client.query(
        `DELETE FROM attestations_pendientes
         WHERE (esquema = 'Finca' AND entidad_id = $1)
            OR (esquema = 'Entrega' AND entidad_id IN (SELECT id FROM entregas WHERE finca_id = $1))
            OR (esquema = 'Verificacion' AND entidad_id IN (SELECT id FROM verificaciones WHERE finca_id = $1))`,
        [fincaId],
      );
      const fotos = await client.query<{ storage_path: string | null }>(
        `DELETE FROM fotos
         WHERE (entidad_tipo = 'finca' AND entidad_id = $1)
            OR (entidad_tipo = 'verificacion' AND entidad_id IN (SELECT id FROM verificaciones WHERE finca_id = $1))
         RETURNING storage_path`,
        [fincaId],
      );
      for (const tabla of ["entregas", "verificaciones", "chequeos_deforestacion", "fincas_versiones"]) {
        await client.query(`DELETE FROM ${tabla} WHERE finca_id = $1`, [fincaId]);
      }
      await client.query("DELETE FROM fincas WHERE id = $1", [fincaId]);
      await client.query("COMMIT");
      return { estado: "eliminada", archivos: fotos.rows.flatMap((f) => (f.storage_path ? [f.storage_path] : [])) };
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async cambiarCultivoFinca(organizacionId: string, fincaId: string, cultivo: string): Promise<ResultadoCambiarCultivo> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const { rows } = await client.query<{ atestada: boolean; con_entregas: boolean }>(
        `SELECT EXISTS (SELECT 1 FROM fincas_versiones fv WHERE fv.finca_id = f.id AND fv.attestation_uid IS NOT NULL)
                OR f.attestation_uid IS NOT NULL AS atestada,
                EXISTS (SELECT 1 FROM entregas e WHERE e.finca_id = f.id AND e.anulada_en IS NULL) AS con_entregas
         FROM fincas f JOIN productores p ON p.id = f.productor_id
         WHERE f.id = $1 AND p.organizacion_id = $2 FOR UPDATE OF f`,
        [fincaId, organizacionId],
      );
      const r = rows[0];
      const estado: ResultadoCambiarCultivo = !r ? "no_encontrada" : r.con_entregas ? "con_entregas" : r.atestada ? "atestada" : "cambiado";
      if (estado !== "cambiado") {
        await client.query("ROLLBACK");
        return estado;
      }
      await client.query("UPDATE fincas SET cultivo = $2 WHERE id = $1", [fincaId, cultivo]);
      await client.query(
        `UPDATE verificaciones SET temporada_id = ${TEMPORADA_DE("$2", "fecha", "$1")} WHERE finca_id = $1`,
        [fincaId, organizacionId],
      );
      await client.query("COMMIT");
      return "cambiado";
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async entregasCandidatas(
    organizacionId: string,
    filtro: { ids: string[] } | { cultivo: string; temporadaId: string },
  ): Promise<EntregaCandidata[]> {
    const [condicion, params] =
      "ids" in filtro
        ? ["e.id = ANY($2::uuid[])", [filtro.ids]]
        : ["f.cultivo = $2 AND e.temporada_id = $3", [filtro.cultivo, filtro.temporadaId]];
    const { rows } = await this.pool.query(
      `SELECT e.id, f.id AS "fincaId", f.nombre AS "fincaNombre", p.nombre AS "productorNombre", f.cultivo,
              e.temporada_id AS "temporadaId", e.kg::float8 AS kg, e.estado, e.fecha, f.deforestacion,
              EXISTS (SELECT 1 FROM verificaciones v
                      WHERE v.finca_id = f.id AND v.temporada_id = e.temporada_id AND v.anulada_en IS NULL)
                AS verificada,
              ${AREA_OFICIAL("f")}::float8 AS "areaOficialHa", l.codigo AS "loteCodigo"
       FROM entregas e JOIN fincas f ON f.id = e.finca_id JOIN productores p ON p.id = f.productor_id
       LEFT JOIN lote_entregas le ON le.entrega_id = e.id LEFT JOIN lotes l ON l.id = le.lote_id
       WHERE p.organizacion_id = $1 AND e.anulada_en IS NULL AND ${condicion}
       ORDER BY e.fecha`,
      [organizacionId, ...params],
    );
    // Rendimiento de cada finca en la temporada: todas sus entregas, no solo
    // las del lote, convertidas al estado exportable (café oro, cacao seco).
    const totales = await this.pool.query<{ finca_id: string; temporada_id: string; cultivo: string; estado: string; kg: number }>(
      `SELECT e.finca_id, e.temporada_id, f.cultivo, e.estado, sum(e.kg)::float8 AS kg
       FROM entregas e JOIN fincas f ON f.id = e.finca_id
       WHERE e.finca_id = ANY($1::uuid[]) AND e.temporada_id IS NOT NULL AND e.anulada_en IS NULL
       GROUP BY 1, 2, 3, 4`,
      [[...new Set(rows.map((r) => r.fincaId))]],
    );
    const exportables = new Map<string, number>();
    for (const t of totales.rows) {
      const c = cultivo(t.cultivo);
      const exportable = c?.estados.find((x) => x.factorExportable === 1);
      if (!c || !exportable || !estadoValido(t.cultivo, t.estado)) continue;
      const clave = `${t.finca_id}/${t.temporada_id}`;
      exportables.set(clave, (exportables.get(clave) ?? 0) + convertirKg(c.id, t.kg, t.estado, exportable.id));
    }
    return rows.map((r) => ({
      ...r,
      fecha: new Date(r.fecha).toISOString(),
      kgExportablesFincaTemporada: exportables.get(`${r.fincaId}/${r.temporadaId}`) ?? 0,
    }));
  }

  async guardarLote(organizacionId: string, uid: string, l: DatosLote): Promise<ResultadoGuardarLote> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `INSERT INTO lotes (id, organizacion_id, codigo, cultivo, temporada_id, estado, kg, kg_esperados,
                            beneficio, proceso, avisos, creado_por)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
        [l.id, organizacionId, l.codigo, l.cultivo, l.temporadaId, l.estado, l.kg, l.kgEsperados,
         l.beneficio, l.proceso ?? null, JSON.stringify(l.avisos), uid],
      );
      await client.query(
        "INSERT INTO lote_entregas (lote_id, entrega_id) SELECT $1, unnest($2::uuid[])",
        [l.id, l.entregas],
      );
      await client.query("INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Lote', $1)", [l.id]);
      await client.query("COMMIT");
      return "creado";
    } catch (e) {
      await client.query("ROLLBACK");
      const restriccion = (e as { constraint?: string }).constraint;
      if (restriccion === "lotes_codigo_unico") return "codigo_repetido";
      if (restriccion === "lote_entregas_entrega_unica") return "entrega_ocupada";
      throw e;
    } finally {
      client.release();
    }
  }

  async listarLotes(organizacionId: string): Promise<Lote[]> {
    const { rows } = await this.pool.query(
      `SELECT l.id, l.codigo, l.cultivo, l.temporada_id AS "temporadaId", t.nombre AS "temporadaNombre", l.estado,
              l.kg::float8 AS kg, l.kg_esperados::float8 AS "kgEsperados", l.beneficio, l.proceso, l.avisos,
              l.attestation_uid AS "attestationUid", l.creado_en AS "creadoEn",
              (SELECT x.codigo FROM exportacion_lotes el JOIN exportaciones x ON x.id = el.exportacion_id
                WHERE el.lote_id = l.id) AS "exportacionCodigo",
              count(DISTINCT f.id)::int AS "fincasTotal",
              (count(DISTINCT f.id) FILTER (WHERE f.deforestacion <> 'verde'))::int AS "fincasSinVerde",
              coalesce(json_agg(json_build_object(
                'id', e.id, 'fincaId', f.id, 'fincaNombre', f.nombre, 'productorNombre', p.nombre,
                'kg', e.kg::float8, 'estado', e.estado, 'fecha', e.fecha
              ) ORDER BY e.fecha) FILTER (WHERE e.id IS NOT NULL), '[]') AS entregas
       FROM lotes l JOIN temporadas t ON t.id = l.temporada_id
       LEFT JOIN lote_entregas le ON le.lote_id = l.id
       LEFT JOIN entregas e ON e.id = le.entrega_id
       LEFT JOIN fincas f ON f.id = e.finca_id
       LEFT JOIN productores p ON p.id = f.productor_id
       WHERE l.organizacion_id = $1
       GROUP BY l.id, t.nombre
       ORDER BY l.creado_en DESC`,
      [organizacionId],
    );
    return rows.map(({ fincasTotal, fincasSinVerde, ...r }) => {
      // El aviso satelital guardado al crear el lote se reemplaza por el actual.
      const satelite = avisoSatelite(fincasSinVerde, fincasTotal);
      const avisos = [...(r.avisos as Aviso[]).filter((a) => a.codigo !== "satelite"), ...(satelite ? [satelite] : [])];
      return {
        ...r,
        avisos,
        creadoEn: new Date(r.creadoEn).toISOString(),
        entregas: r.entregas.map((e: { fecha: string }) => ({ ...e, fecha: new Date(e.fecha).toISOString() })),
      };
    });
  }

  async eliminarLote(organizacionId: string, loteId: string): Promise<ResultadoEliminarLote> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const { rows } = await client.query<{ atestado: boolean }>(
        `SELECT attestation_uid IS NOT NULL
                OR EXISTS (SELECT 1 FROM exportacion_lotes x WHERE x.lote_id = l.id) AS atestado
         FROM lotes l WHERE l.id = $1 AND l.organizacion_id = $2 FOR UPDATE`,
        [loteId, organizacionId],
      );
      if (rows.length === 0 || rows[0].atestado) {
        await client.query("ROLLBACK");
        return rows.length === 0 ? "no_encontrado" : "atestado";
      }
      await client.query("DELETE FROM attestations_pendientes WHERE esquema = 'Lote' AND entidad_id = $1", [loteId]);
      await client.query("DELETE FROM lote_entregas WHERE lote_id = $1", [loteId]);
      await client.query("DELETE FROM lotes WHERE id = $1", [loteId]);
      await client.query("COMMIT");
      return "eliminado";
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async lotesCandidatos(organizacionId: string, ids: string[]): Promise<LoteCandidato[]> {
    const { rows } = await this.pool.query<LoteCandidato>(
      `SELECT l.id, l.codigo, l.cultivo, x.codigo AS "exportacionCodigo"
       FROM lotes l
       LEFT JOIN exportacion_lotes el ON el.lote_id = l.id
       LEFT JOIN exportaciones x ON x.id = el.exportacion_id
       WHERE l.organizacion_id = $1 AND l.id = ANY($2::uuid[])`,
      [organizacionId, ids],
    );
    return rows;
  }

  async guardarExportacion(
    organizacionId: string,
    uid: string,
    x: ExportacionNueva & { id: string; cultivo: string },
  ): Promise<ResultadoGuardarExportacion> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `INSERT INTO exportaciones (id, organizacion_id, codigo, cultivo, comprador, destino, contenedor,
                                    fecha_embarque, creado_por)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [x.id, organizacionId, x.codigo, x.cultivo, x.comprador, x.destino, x.contenedor ?? null,
         x.fechaEmbarque ?? null, uid],
      );
      await client.query(
        "INSERT INTO exportacion_lotes (exportacion_id, lote_id) SELECT $1, unnest($2::uuid[])",
        [x.id, x.lotes],
      );
      await client.query("COMMIT");
      return "creada";
    } catch (e) {
      await client.query("ROLLBACK");
      const restriccion = (e as { constraint?: string }).constraint;
      if (restriccion === "exportaciones_codigo_unico") return "codigo_repetido";
      if (restriccion === "exportacion_lotes_lote_unico") return "lote_ocupado";
      throw e;
    } finally {
      client.release();
    }
  }

  async listarExportaciones(organizacionId: string): Promise<Exportacion[]> {
    const { rows } = await this.pool.query(
      `SELECT x.id, x.codigo, x.cultivo, x.comprador, x.destino, x.contenedor,
              to_char(x.fecha_embarque, 'YYYY-MM-DD') AS "fechaEmbarque", x.dds_ref AS "ddsRef", x.estado,
              x.attestation_uid AS "attestationUid", x.creado_en AS "creadoEn",
              coalesce((SELECT sum(l.kg)::float8 FROM exportacion_lotes el JOIN lotes l ON l.id = el.lote_id
                        WHERE el.exportacion_id = x.id), 0) AS kg,
              coalesce((SELECT json_agg(json_build_object(
                          'id', l.id, 'codigo', l.codigo, 'kg', l.kg::float8, 'estado', l.estado,
                          'temporadaNombre', t.nombre) ORDER BY l.codigo)
                        FROM exportacion_lotes el JOIN lotes l ON l.id = el.lote_id
                        JOIN temporadas t ON t.id = l.temporada_id
                        WHERE el.exportacion_id = x.id), '[]') AS lotes,
              (SELECT json_build_object(
                        'entregas', count(DISTINCT e.id),
                        'fincas', count(DISTINCT f.id),
                        'fincasSinVerde', count(DISTINCT f.id) FILTER (WHERE f.deforestacion <> 'verde'))
               FROM exportacion_lotes el JOIN lote_entregas le ON le.lote_id = el.lote_id
               JOIN entregas e ON e.id = le.entrega_id JOIN fincas f ON f.id = e.finca_id
               WHERE el.exportacion_id = x.id) AS resumen,
              (SELECT coalesce(sum(${AREA_OFICIAL("f")}), 0)::float8 FROM fincas f WHERE f.id IN (
                 SELECT e.finca_id FROM exportacion_lotes el JOIN lote_entregas le ON le.lote_id = el.lote_id
                 JOIN entregas e ON e.id = le.entrega_id WHERE el.exportacion_id = x.id)) AS "areaOficialHa"
       FROM exportaciones x
       WHERE x.organizacion_id = $1
       ORDER BY x.creado_en DESC`,
      [organizacionId],
    );
    return rows.map(({ areaOficialHa, ...r }) => ({
      ...r,
      creadoEn: new Date(r.creadoEn).toISOString(),
      resumen: { ...r.resumen, areaOficialHa },
    }));
  }

  async actualizarExportacion(
    organizacionId: string,
    id: string,
    c: CambiosExportacion,
  ): Promise<ResultadoCambiarExportacion> {
    const columnas: Record<keyof CambiosExportacion, string> = {
      comprador: "comprador",
      destino: "destino",
      contenedor: "contenedor",
      fechaEmbarque: "fecha_embarque",
      ddsRef: "dds_ref",
    };
    const campos = (Object.keys(c) as (keyof CambiosExportacion)[]).filter((k) => c[k] !== undefined);
    const sets = campos.map((k, i) => `${columnas[k]} = $${i + 4}`).join(", ");
    // La referencia de la DDS llega después del paquete EUDR: se puede anotar
    // con el contenedor cerrado mientras su attestation no se haya firmado.
    const soloDds = campos.every((k) => k === "ddsRef");
    const { rows } = await this.pool.query<{ estado: string; cambiada: boolean }>(
      `WITH actual AS (SELECT id, estado, attestation_uid FROM exportaciones WHERE id = $1 AND organizacion_id = $2),
            cambio AS (UPDATE exportaciones SET ${sets}
                       WHERE id = (SELECT id FROM actual
                                   WHERE estado = 'abierta' OR ($3 AND attestation_uid IS NULL))
                       RETURNING id)
       SELECT a.estado, EXISTS (SELECT 1 FROM cambio) AS cambiada FROM actual a`,
      [id, organizacionId, soloDds, ...campos.map((k) => c[k] ?? null)],
    );
    if (rows.length === 0) return "no_encontrada";
    return rows[0].cambiada ? "cambiada" : "cerrada";
  }

  async eliminarExportacion(organizacionId: string, id: string): Promise<ResultadoCambiarExportacion> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const { rows } = await client.query<{ abierta: boolean }>(
        `SELECT estado = 'abierta' AND attestation_uid IS NULL AS abierta
         FROM exportaciones WHERE id = $1 AND organizacion_id = $2 FOR UPDATE`,
        [id, organizacionId],
      );
      if (rows.length === 0 || !rows[0].abierta) {
        await client.query("ROLLBACK");
        return rows.length === 0 ? "no_encontrada" : "cerrada";
      }
      await client.query("DELETE FROM exportacion_lotes WHERE exportacion_id = $1", [id]);
      await client.query("DELETE FROM exportaciones WHERE id = $1", [id]);
      await client.query("COMMIT");
      return "cambiada";
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async paqueteExportacion(organizacionId: string, id: string): Promise<Paquete | null> {
    const exportacion = (await this.listarExportaciones(organizacionId)).find((x) => x.id === id);
    if (!exportacion) return null;
    const organizacion = (await this.organizacion(organizacionId))!.nombre;
    const { rows } = await this.pool.query(
      `WITH entregas_x AS (
         SELECT e.finca_id, sum(e.kg)::float8 AS kg
         FROM exportacion_lotes el JOIN lote_entregas le ON le.lote_id = el.lote_id
         JOIN entregas e ON e.id = le.entrega_id
         WHERE el.exportacion_id = $1
         GROUP BY e.finca_id)
       SELECT f.id, f.nombre, p.nombre AS "productorNombre", p.comunidad,
              ST_AsGeoJSON(f.geom, 8)::json AS geometria, ${AREA_OFICIAL("f")}::float8 AS "areaOficialHa",
              f.version_actual AS version, f.geo_hash AS "geoHash", f.deforestacion,
              (SELECT max(c.fecha) FROM chequeos_deforestacion c WHERE c.finca_id = f.id) AS "ultimoChequeo",
              (SELECT max(v.fecha) FROM verificaciones v WHERE v.finca_id = f.id) AS "ultimaVisita",
              f.attestation_uid AS "attestationUid", x.kg AS "kgEntregados"
       FROM entregas_x x JOIN fincas f ON f.id = x.finca_id JOIN productores p ON p.id = f.productor_id
       ORDER BY f.nombre`,
      [id],
    );
    const iso = (d: Date | null) => (d ? new Date(d).toISOString() : null);
    return {
      organizacion,
      exportacion,
      fincas: rows.map((f) => ({ ...f, ultimoChequeo: iso(f.ultimoChequeo), ultimaVisita: iso(f.ultimaVisita) })),
    };
  }

  async cerrarExportacion(organizacionId: string, id: string): Promise<ResultadoCambiarExportacion> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const r = await client.query(
        "UPDATE exportaciones SET estado = 'cerrada' WHERE id = $1 AND organizacion_id = $2 AND estado = 'abierta'",
        [id, organizacionId],
      );
      if (r.rowCount === 0) {
        await client.query("ROLLBACK");
        const existe = await this.pool.query("SELECT 1 FROM exportaciones WHERE id = $1 AND organizacion_id = $2", [id, organizacionId]);
        return existe.rowCount === 0 ? "no_encontrada" : "cerrada";
      }
      await client.query(
        "INSERT INTO attestations_pendientes (esquema, entidad_id) VALUES ('Exportacion', $1) ON CONFLICT DO NOTHING",
        [id],
      );
      await client.query("COMMIT");
      return "cambiada";
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async datosOrganizacion(organizacionId: string): Promise<DatosOrganizacion> {
    const organizacion = (await this.organizacion(organizacionId))!;
    const temporadas = await this.listarTemporadas(organizacionId);
    const productores = await this.pool.query(
      `SELECT id, nombre, cedula, comunidad, consentimiento_firmado AS "consentimientoFirmado"
       FROM productores WHERE organizacion_id = $1 ORDER BY nombre`,
      [organizacionId],
    );
    // 15 decimales: las mismas coordenadas que mandó la app, para que el
    // geoHash se pueda recalcular en cualquier celular.
    const fincas = await this.pool.query(
      `SELECT f.id, f.productor_id AS "productorId", f.nombre, f.cultivo, ST_AsGeoJSON(f.geom, 15)::json AS geom,
              f.area_ha::float8 AS "areaHa", ${AREA_OFICIAL("f")}::float8 AS "areaOficialHa",
              f.geo_hash AS "geoHash", f.version_actual AS version, f.deforestacion,
              (SELECT max(c.fecha) FROM chequeos_deforestacion c WHERE c.finca_id = f.id) AS "ultimoChequeo",
              f.attestation_uid AS "attestationUid"
       FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE p.organizacion_id = $1 ORDER BY f.creado_en`,
      [organizacionId],
    );
    const verificaciones = await this.pool.query(
      `SELECT v.id, v.finca_id AS "fincaId", v.temporada_id AS "temporadaId", v.fecha,
              v.lindero_cambio AS "linderoCambio", v.version_finca AS "versionFinca", v.nota
       FROM verificaciones v JOIN fincas f ON f.id = v.finca_id JOIN productores p ON p.id = f.productor_id
       WHERE p.organizacion_id = $1 AND v.anulada_en IS NULL ORDER BY v.fecha`,
      [organizacionId],
    );
    const entregas = await this.pool.query(
      `SELECT e.id, e.finca_id AS "fincaId", e.temporada_id AS "temporadaId", e.kg::float8 AS kg, e.estado,
              e.fecha, e.attestation_uid AS "attestationUid",
              (SELECT l.codigo FROM lote_entregas le JOIN lotes l ON l.id = le.lote_id WHERE le.entrega_id = e.id) AS "loteCodigo",
              EXISTS (SELECT 1 FROM correcciones c WHERE c.entidad = 'entrega' AND c.entidad_id = e.id::text) AS corregida
       FROM entregas e JOIN fincas f ON f.id = e.finca_id JOIN productores p ON p.id = f.productor_id
       WHERE p.organizacion_id = $1 AND e.anulada_en IS NULL ORDER BY e.fecha`,
      [organizacionId],
    );
    const iso = (d: Date | null) => (d ? new Date(d).toISOString() : null);
    return {
      organizacion,
      temporadas,
      productores: productores.rows,
      fincas: fincas.rows.map(({ geom, ultimoChequeo, ...f }) => ({
        ...f,
        coordenadas: desdeGeometria(geom),
        ultimoChequeo: iso(ultimoChequeo),
      })),
      verificaciones: verificaciones.rows.map((v) => ({ ...v, fecha: iso(v.fecha)! })),
      entregas: entregas.rows.map((e) => ({ ...e, fecha: iso(e.fecha)! })),
    };
  }

  async buscarFoto(organizacionId: string, fotoId: string) {
    const { rows } = await this.pool.query<{ sha256: string; storagePath: string | null }>(
      `SELECT sha256, storage_path AS "storagePath" FROM fotos WHERE id = $1 AND organizacion_id = $2`,
      [fotoId, organizacionId],
    );
    return rows[0] ?? null;
  }

  async marcarFotoSubida(fotoId: string, storagePath: string): Promise<void> {
    await this.pool.query("UPDATE fotos SET storage_path = $2 WHERE id = $1", [fotoId, storagePath]);
  }

  async organizacion(organizacionId: string): Promise<Organizacion | null> {
    const { rows } = await this.pool.query<Organizacion>(
      "SELECT id, nombre, tipo, cultivos FROM organizaciones WHERE id = $1",
      [organizacionId],
    );
    return rows[0] ?? null;
  }

  async actualizarCultivos(organizacionId: string, cultivos: string[]): Promise<string[]> {
    const { rows } = await this.pool.query<{ cultivo: string }>(
      `SELECT DISTINCT f.cultivo FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE p.organizacion_id = $1 AND NOT (f.cultivo = ANY($2::text[]))`,
      [organizacionId, cultivos],
    );
    if (rows.length > 0) return rows.map((r) => r.cultivo);
    await this.pool.query("UPDATE organizaciones SET cultivos = $2 WHERE id = $1", [organizacionId, cultivos]);
    return [];
  }

  async listarTemporadas(organizacionId: string): Promise<Temporada[]> {
    const { rows } = await this.pool.query<Temporada>(
      `SELECT id, nombre, to_char(inicio, 'YYYY-MM-DD') AS inicio, to_char(fin, 'YYYY-MM-DD') AS fin, cultivo
       FROM temporadas WHERE organizacion_id = $1 ORDER BY inicio DESC, cultivo NULLS FIRST`,
      [organizacionId],
    );
    return rows;
  }

  async crearTemporada(organizacionId: string, t: TemporadaNueva & { id: string }, uid: string) {
    const client = await this.pool.connect();
    const cultivoT = t.cultivo ?? null;
    try {
      await client.query("BEGIN");
      await client.query(
        `INSERT INTO temporadas (id, organizacion_id, nombre, inicio, fin, cultivo, creado_por)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [t.id, organizacionId, t.nombre, t.inicio, t.fin, cultivoT, uid],
      );
      // Lo que llegó antes queda asignado ahora: lo que no tenía temporada y,
      // si esta es de un cultivo, lo de ese cultivo que estaba en una
      // temporada general (la específica tiene prioridad).
      for (const tabla of ["entregas", "verificaciones"]) {
        await client.query(
          `UPDATE ${tabla} x SET temporada_id = $1
           FROM fincas f JOIN productores p ON p.id = f.productor_id
           WHERE x.finca_id = f.id AND p.organizacion_id = $2
             AND ($5::text IS NULL OR f.cultivo = $5)
             AND (x.temporada_id IS NULL OR ($5::text IS NOT NULL AND x.temporada_id IN
                   (SELECT id FROM temporadas WHERE organizacion_id = $2 AND cultivo IS NULL)))
             AND (x.fecha AT TIME ZONE 'America/Managua')::date BETWEEN $3 AND $4`,
          [t.id, organizacionId, t.inicio, t.fin, cultivoT],
        );
      }
      await client.query("COMMIT");
      return { id: t.id, nombre: t.nombre, inicio: t.inicio, fin: t.fin, cultivo: cultivoT };
    } catch (e) {
      await client.query("ROLLBACK");
      if ((e as { constraint?: string }).constraint === "temporadas_sin_traslape") return null;
      throw e;
    } finally {
      client.release();
    }
  }

  async fincasPorRevisar(limite: number): Promise<FincaPorRevisar[]> {
    // La temporada de cada finca depende de su cultivo (TEMPORADA_ACTUAL_DE_F).
    const { rows } = await this.pool.query(
      `SELECT * FROM (
         SELECT f.id AS "fincaId", f.version_actual AS version, f.creado_en,
                ${TEMPORADA_ACTUAL_DE_F} AS "temporadaId", ${GEOMETRIA_SATELITE} AS geometria
         FROM fincas f JOIN productores p ON p.id = f.productor_id
       ) x
       WHERE x."temporadaId" IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM chequeos_deforestacion c
         WHERE c.finca_id = x."fincaId" AND c.temporada_id = x."temporadaId" AND c.version_finca = x.version)
       ORDER BY x.creado_en
       LIMIT $1`,
      [limite],
    );
    return rows.map(({ creado_en: _, ...f }) => f);
  }

  async fincaParaRevisar(organizacionId: string, fincaId: string): Promise<FincaPorRevisar | null> {
    const { rows } = await this.pool.query(
      `SELECT f.id AS "fincaId", f.version_actual AS version,
              ${TEMPORADA_ACTUAL_DE_F} AS "temporadaId",
              ${GEOMETRIA_SATELITE} AS geometria
       FROM fincas f JOIN productores p ON p.id = f.productor_id
       WHERE f.id = $1 AND p.organizacion_id = $2`,
      [fincaId, organizacionId],
    );
    return rows[0] ?? null;
  }

  async guardarChequeo(c: Chequeo): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      // Un chequeo nuevo de la misma temporada y versión reemplaza al anterior.
      await client.query(
        `INSERT INTO chequeos_deforestacion
           (finca_id, temporada_id, version_finca, fuente, alertas, area_afectada_ha, resultado, detalle)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (finca_id, temporada_id, version_finca) DO UPDATE SET
           fecha = now(), fuente = EXCLUDED.fuente, alertas = EXCLUDED.alertas,
           area_afectada_ha = EXCLUDED.area_afectada_ha, resultado = EXCLUDED.resultado, detalle = EXCLUDED.detalle,
           attestation_uid = NULL`,
        [c.fincaId, c.temporadaId, c.version, c.fuente, c.alertas, c.areaAfectadaHa, c.resultado, JSON.stringify(c.detalle)],
      );
      // Solo si el chequeo es del lindero vigente cambia el estado de la finca.
      await client.query("UPDATE fincas SET deforestacion = $2 WHERE id = $1 AND version_actual = $3", [
        c.fincaId,
        c.resultado,
        c.version,
      ]);
      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }
}

/** Un punto si hay una coordenada; si no, un polígono con el anillo cerrado. */
export function aGeometria(coords: [number, number][]) {
  if (coords.length === 1) return { type: "Point", coordinates: coords[0] };
  return { type: "Polygon", coordinates: [[...coords, coords[0]]] };
}

/** Lo inverso de `aGeometria`: el anillo abierto, como lo guarda la app. */
export function desdeGeometria(g: { type: string; coordinates: unknown }): [number, number][] {
  if (g.type === "Point") return [g.coordinates as [number, number]];
  return (g.coordinates as [number, number][][])[0].slice(0, -1);
}
