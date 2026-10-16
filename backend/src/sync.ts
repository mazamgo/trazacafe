import { geoHash, problemaPoligono, type Coordenada, type ProblemaPoligono } from "@trazacafe/eudr-eas-schemas";
import { z } from "zod";

const UMBRAL_POLIGONO_HA = 4;

const MENSAJES_POLIGONO: Record<ProblemaPoligono, string> = {
  pocos_puntos: "El polígono necesita al menos 3 puntos",
  puntos_repetidos: "El polígono tiene dos puntos seguidos repetidos",
  se_cruza: "Los linderos del polígono se cruzan (TRACES rechaza polígonos inválidos)",
};

const coordenada = z.tuple([z.number().min(-180).max(180), z.number().min(-90).max(90)]);

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
    coordenadas: z.array(coordenada).min(1),
    areaHa: z.number().positive(),
    geoHash: z.string().regex(/^0x[0-9a-f]{64}$/),
  })
  .superRefine((f, ctx) => {
    if (f.coordenadas.length === 2) {
      ctx.addIssue({ code: "custom", message: "Use 1 punto o un polígono de al menos 3 vértices" });
    }
    if (f.coordenadas.length >= 3) {
      const problema = problemaPoligono(f.coordenadas as Coordenada[]);
      if (problema) {
        ctx.addIssue({ code: "custom", path: ["coordenadas"], message: MENSAJES_POLIGONO[problema] });
      }
    }
    if (f.coordenadas.length === 1 && f.areaHa >= UMBRAL_POLIGONO_HA) {
      ctx.addIssue({ code: "custom", message: "Fincas de 4 ha o más necesitan polígono (EUDR)" });
    }
    // El hash se recalcula aquí: si no coincide, las coordenadas se alteraron
    // o la app y el backend no canonizan igual.
    if (geoHash(f.coordenadas as Coordenada[]) !== f.geoHash) {
      ctx.addIssue({ code: "custom", path: ["geoHash"], message: "geoHash no coincide con las coordenadas" });
    }
  });

/** Entrega de café de una finca al beneficio húmedo. */
export const entregaSchema = z
  .object({
    id: z.uuid(),
    fincaId: z.uuid(),
    // Un camión grande lleva ~15 t; más que eso en una entrega es un error de digitación.
    kg: z.number().positive().max(20_000),
    estado: z.enum(["uva", "pergamino"]),
    fecha: z.iso.datetime({ offset: true }),
  })
  .refine((e) => Date.parse(e.fecha) <= Date.now() + 24 * 3600_000, {
    path: ["fecha"],
    message: "La fecha de la entrega no puede estar en el futuro",
  });

/** Llega el hash; el archivo se sube aparte a Cloud Storage y se confirma con /v1/fotos/:id/subida. */
export const fotoSchema = z.object({
  id: z.uuid(),
  entidadTipo: z.enum(["productor", "finca"]),
  entidadId: z.uuid(),
  tipo: z.enum(["consentimiento", "finca", "documento"]),
  sha256: z.string().regex(/^0x[0-9a-f]{64}$/),
});

export const syncSchema = z.object({
  productores: z.array(productorSchema).default([]),
  fincas: z.array(fincaSchema).default([]),
  entregas: z.array(entregaSchema).default([]),
  fotos: z.array(fotoSchema).default([]),
});

export type Productor = z.infer<typeof productorSchema>;
export type FincaSync = z.infer<typeof fincaSchema>;
export type EntregaSync = z.infer<typeof entregaSchema>;
export type FotoSync = z.infer<typeof fotoSchema>;
export type LoteSync = z.infer<typeof syncSchema>;
