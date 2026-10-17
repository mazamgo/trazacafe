import {
  geoHash,
  ID_CULTIVOS,
  problemaPoligono,
  TODOS_LOS_ESTADOS,
  type Coordenada,
  type ProblemaPoligono,
} from "@trazacafe/eudr-eas-schemas";
import { z } from "zod";

const UMBRAL_POLIGONO_HA = 4;

const MENSAJES_POLIGONO: Record<ProblemaPoligono, string> = {
  pocos_puntos: "El polígono necesita al menos 3 puntos",
  puntos_repetidos: "El polígono tiene dos puntos seguidos repetidos",
  se_cruza: "Los linderos del polígono se cruzan (TRACES rechaza polígonos inválidos)",
};

const coordenada = z.tuple([z.number().min(-180).max(180), z.number().min(-90).max(90)]);

/** Fecha con zona horaria que no esté en el futuro (margen de un día). */
const fechaPasada = (que: string) =>
  z.iso.datetime({ offset: true }).refine((f) => Date.parse(f) <= Date.now() + 24 * 3600_000, {
    message: `La fecha de ${que} no puede estar en el futuro`,
  });

/** Reglas de geometría de una finca, iguales para la primera versión y las siguientes. */
function validarGeometria(
  g: { coordenadas: [number, number][]; areaHa: number; geoHash: string },
  ctx: z.RefinementCtx,
) {
  if (g.coordenadas.length === 2) {
    ctx.addIssue({ code: "custom", message: "Use 1 punto o un polígono de al menos 3 vértices" });
  }
  if (g.coordenadas.length >= 3) {
    const problema = problemaPoligono(g.coordenadas as Coordenada[]);
    if (problema) {
      ctx.addIssue({ code: "custom", path: ["coordenadas"], message: MENSAJES_POLIGONO[problema] });
    }
  }
  if (g.coordenadas.length === 1 && g.areaHa >= UMBRAL_POLIGONO_HA) {
    ctx.addIssue({ code: "custom", message: "Fincas de 4 ha o más necesitan polígono (EUDR)" });
  }
  // El hash se recalcula aquí: si no coincide, las coordenadas se alteraron
  // o la app y el backend no canonizan igual.
  if (geoHash(g.coordenadas as Coordenada[]) !== g.geoHash) {
    ctx.addIssue({ code: "custom", path: ["geoHash"], message: "geoHash no coincide con las coordenadas" });
  }
}

export const productorSchema = z.object({
  id: z.uuid(),
  nombre: z.string().min(1),
  cedula: z.string().nullish(),
  comunidad: z.string().nullish(),
  consentimientoFirmado: z.literal(true, {
    error: "Falta el consentimiento firmado del productor (Ley 787)",
  }),
});

export const fincaSchema = z
  .object({
    id: z.uuid(),
    productorId: z.uuid(),
    nombre: z.string().min(1),
    // Las apps anteriores al multicultivo no lo mandan: eran todas de café.
    cultivo: z.enum(ID_CULTIVOS).default("cafe"),
    coordenadas: z.array(coordenada).min(1),
    areaHa: z.number().positive(),
    geoHash: z.string().regex(/^0x[0-9a-f]{64}$/),
  })
  .superRefine(validarGeometria);

/** Lindero nuevo de una finca existente (después de una visita). No reemplaza al anterior. */
export const versionFincaSchema = z
  .object({
    fincaId: z.uuid(),
    version: z.number().int().min(2),
    coordenadas: z.array(coordenada).min(1),
    areaHa: z.number().positive(),
    geoHash: z.string().regex(/^0x[0-9a-f]{64}$/),
  })
  .superRefine(validarGeometria);

/** Visita de verificación de una finca; la temporada la asigna la API por la fecha. */
export const verificacionSchema = z.object({
  id: z.uuid(),
  fincaId: z.uuid(),
  fecha: fechaPasada("la visita"),
  linderoCambio: z.boolean(),
  /** Versión del lindero vigente al terminar la visita. */
  versionFinca: z.number().int().min(1),
  nota: z.string().max(2000).nullish(),
});

/** Entrega de café de una finca al beneficio húmedo. */
export const entregaSchema = z.object({
  id: z.uuid(),
  fincaId: z.uuid(),
  // Un camión grande lleva ~15 t; más que eso en una entrega es un error de digitación.
  kg: z.number().positive().max(20_000),
  // Que el estado corresponda al cultivo de la finca se revisa al guardar.
  estado: z.enum(TODOS_LOS_ESTADOS as [string, ...string[]]),
  fecha: fechaPasada("la entrega"),
});

/** Llega el hash; el archivo se sube aparte a Cloud Storage y se confirma con /v1/fotos/:id/subida. */
export const fotoSchema = z.object({
  id: z.uuid(),
  entidadTipo: z.enum(["productor", "finca", "verificacion"]),
  entidadId: z.uuid(),
  tipo: z.enum(["consentimiento", "finca", "documento", "verificacion"]),
  sha256: z.string().regex(/^0x[0-9a-f]{64}$/),
});

export const syncSchema = z.object({
  productores: z.array(productorSchema).default([]),
  fincas: z.array(fincaSchema).default([]),
  versionesFinca: z.array(versionFincaSchema).default([]),
  verificaciones: z.array(verificacionSchema).default([]),
  entregas: z.array(entregaSchema).default([]),
  fotos: z.array(fotoSchema).default([]),
});

export const temporadaSchema = z
  .object({
    nombre: z.string().trim().min(1).max(40),
    inicio: z.iso.date(),
    fin: z.iso.date(),
    /** Vacío = la temporada aplica a todos los cultivos de la organización. */
    cultivo: z.enum(ID_CULTIVOS).nullish(),
  })
  .refine((t) => t.inicio < t.fin, { path: ["fin"], message: "La temporada debe terminar después de empezar" });

export const cambioCultivoSchema = z.object({ cultivo: z.enum(ID_CULTIVOS) });

export const cultivosOrganizacionSchema = z.object({
  cultivos: z.array(z.enum(ID_CULTIVOS)).min(1, "La organización debe tener al menos un cultivo"),
});

export type Productor = z.infer<typeof productorSchema>;
export type FincaSync = z.infer<typeof fincaSchema>;
export type VersionFincaSync = z.infer<typeof versionFincaSchema>;
export type VerificacionSync = z.infer<typeof verificacionSchema>;
export type EntregaSync = z.infer<typeof entregaSchema>;
export type FotoSync = z.infer<typeof fotoSchema>;
export type LoteSync = z.infer<typeof syncSchema>;
export type TemporadaNueva = z.infer<typeof temporadaSchema>;
