import { z } from "zod";

/**
 * Número de contenedor ISO 6346 normalizado (`MSCU1234565`), o `null` si el
 * formato o el dígito de control no cuadran (suele ser un error de tipeo).
 */
export function contenedorValido(texto: string): string | null {
  const c = texto.toUpperCase().replace(/[\s-]/g, "");
  if (!/^[A-Z]{3}[UJZ][0-9]{7}$/.test(c)) return null;
  // Letras: A=10 … Z=38, saltando los múltiplos de 11.
  const valor = (ch: string) => {
    if (/[0-9]/.test(ch)) return Number(ch);
    let v = 10;
    for (let x = 65; x < ch.charCodeAt(0); x++) {
      v++;
      if (v % 11 === 0) v++;
    }
    return v;
  };
  let suma = 0;
  for (let i = 0; i < 10; i++) suma += valor(c[i]) * 2 ** i;
  return (suma % 11) % 10 === Number(c[10]) ? c : null;
}

const contenedor = z
  .string()
  .trim()
  .transform((s, ctx) => {
    const c = contenedorValido(s);
    if (!c) {
      ctx.addIssue({
        code: "custom",
        message: "Número de contenedor inválido: 4 letras y 7 dígitos (ISO 6346), revisa el dígito de control",
      });
      return z.NEVER;
    }
    return c;
  });

const textoCorto = (max: number) => z.string().trim().min(1).max(max);

export const exportacionSchema = z
  .object({
    codigo: textoCorto(40),
    comprador: textoCorto(120),
    /** Puerto o país de destino, p. ej. "Hamburgo, Alemania". */
    destino: textoCorto(120),
    contenedor: contenedor.nullish(),
    fechaEmbarque: z.iso.date().nullish(),
    lotes: z.array(z.uuid()).min(1, "Elige al menos un lote").max(500),
  })
  .refine((x) => new Set(x.lotes).size === x.lotes.length, { path: ["lotes"], message: "Hay lotes repetidos" });

export type ExportacionNueva = z.infer<typeof exportacionSchema>;

/** Lo que se puede corregir mientras el contenedor está abierto. */
export const cambiosExportacionSchema = z
  .object({
    comprador: textoCorto(120),
    destino: textoCorto(120),
    contenedor: contenedor.nullable(),
    fechaEmbarque: z.iso.date().nullable(),
    /** Referencia de la declaración de diligencia debida en TRACES. */
    ddsRef: z.string().trim().min(1).max(60).nullable(),
  })
  .partial()
  .refine((x) => Object.keys(x).length > 0, { message: "Nada que cambiar" });

export type CambiosExportacion = z.infer<typeof cambiosExportacionSchema>;

/** Lote con lo necesario para decidir si puede ir en un contenedor. */
export interface LoteCandidato {
  id: string;
  codigo: string;
  cultivo: string;
  /** Código del contenedor en que ya está, o `null`. */
  exportacionCodigo: string | null;
}

/**
 * Revisa los lotes de un contenedor nuevo: deben existir en la organización,
 * estar libres y ser de un mismo cultivo. Devuelve el cultivo o los motivos.
 */
export function evaluarExportacion(
  pedidos: string[],
  candidatos: LoteCandidato[],
): { cultivo: string | null; rechazos: { loteId: string; motivo: string }[] } {
  const porId = new Map(candidatos.map((l) => [l.id, l]));
  const rechazos: { loteId: string; motivo: string }[] = [];
  const cultivos = new Set<string>();
  for (const id of pedidos) {
    const l = porId.get(id);
    if (!l) rechazos.push({ loteId: id, motivo: "No existe o es de otra organización" });
    else if (l.exportacionCodigo) rechazos.push({ loteId: id, motivo: `${l.codigo} ya está en el contenedor ${l.exportacionCodigo}` });
    else cultivos.add(l.cultivo);
  }
  if (cultivos.size > 1) {
    for (const id of pedidos) {
      const l = porId.get(id);
      if (l && !l.exportacionCodigo) rechazos.push({ loteId: id, motivo: "Un contenedor lleva lotes de un solo cultivo" });
    }
  }
  return { cultivo: rechazos.length === 0 ? [...cultivos][0] : null, rechazos };
}
