import { geoHash, type Coordenada } from "@trazacafe/eudr-eas-schemas";
import { z } from "zod";

const UMBRAL_POLIGONO_HA = 4;

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
    if (f.coordenadas.length === 1 && f.areaHa >= UMBRAL_POLIGONO_HA) {
      ctx.addIssue({ code: "custom", message: "Fincas de 4 ha o más necesitan polígono (EUDR)" });
    }
    // El hash se recalcula aquí: si no coincide, las coordenadas se alteraron
    // o la app y el backend no canonizan igual.
    if (geoHash(f.coordenadas as Coordenada[]) !== f.geoHash) {
      ctx.addIssue({ code: "custom", path: ["geoHash"], message: "geoHash no coincide con las coordenadas" });
    }
  });

export const syncSchema = z.object({
  productores: z.array(productorSchema).default([]),
  fincas: z.array(fincaSchema).default([]),
});

export type Productor = z.infer<typeof productorSchema>;
export type FincaSync = z.infer<typeof fincaSchema>;
export type LoteSync = z.infer<typeof syncSchema>;
