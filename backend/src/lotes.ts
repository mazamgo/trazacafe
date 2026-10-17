import { convertirKg, cultivo, estadoValido, ID_CULTIVOS } from "@trazacafe/eudr-eas-schemas";
import { z } from "zod";
import type { EstadoDeforestacion } from "./repo.ts";

/** Lo que manda el administrador para armar un lote. */
export const loteSchema = z
  .object({
    codigo: z.string().trim().min(1).max(40),
    cultivo: z.enum(ID_CULTIVOS),
    temporadaId: z.uuid(),
    /** Estado del producto del lote (p. ej. pergamino); debe ser de su cultivo. */
    estado: z.string().regex(/^[a-z_]+$/),
    /** Peso real del lote en la báscula del beneficio. */
    kg: z.number().positive().max(1_000_000),
    beneficio: z.string().trim().min(1).max(80).optional(),
    proceso: z.string().trim().max(40).nullish(),
    entregas: z.array(z.uuid()).min(1, "Elige al menos una entrega").max(2000),
  })
  .refine((l) => estadoValido(l.cultivo, l.estado), {
    path: ["estado"],
    message: "Ese estado no es del cultivo del lote",
  })
  .refine((l) => new Set(l.entregas).size === l.entregas.length, {
    path: ["entregas"],
    message: "Hay entregas repetidas",
  });

export type LoteNuevo = z.infer<typeof loteSchema>;

/** Entrega con lo necesario para decidir si puede ir a un lote. */
export interface EntregaCandidata {
  id: string;
  fincaId: string;
  fincaNombre: string;
  productorNombre: string;
  cultivo: string;
  temporadaId: string | null;
  kg: number;
  estado: string;
  fecha: string;
  deforestacion: EstadoDeforestacion;
  /** ¿La finca tiene visita de verificación en la temporada de la entrega? */
  verificada: boolean;
  areaOficialHa: number;
  /** Kg exportables de todas las entregas de la finca en esa temporada. */
  kgExportablesFincaTemporada: number;
  /** Código del lote en que ya está, o `null`. */
  loteCodigo: string | null;
}

export interface Aviso {
  codigo: "volumen" | "rendimiento" | "satelite";
  mensaje: string;
}

export interface Rechazo {
  entregaId: string;
  motivo: string;
}

/** Tolerancia del control de volumen: humedad, redondeos de báscula. */
export const TOLERANCIA_VOLUMEN = 0.1;

/**
 * Por qué una entrega no puede ir en un lote de ese cultivo y temporada, o
 * `null` si puede. Reglas EUDR: nada de fincas con deforestación ni fincas
 * sin visita en la temporada.
 */
export function motivoExclusion(e: EntregaCandidata, cultivoLote: string, temporadaId: string): string | null {
  if (e.loteCodigo) return `Ya está en el lote ${e.loteCodigo}`;
  if (e.cultivo !== cultivoLote) return `Es de ${cultivo(e.cultivo)?.nombre.toLowerCase() ?? e.cultivo}, no del cultivo del lote`;
  if (e.temporadaId !== temporadaId) return "Es de otra temporada";
  if (e.deforestacion === "rojo") return "La finca tiene pérdida de bosque después de 2020";
  if (!e.verificada) return "La finca no tiene la visita de verificación de la temporada";
  return null;
}

const kg = (n: number) => n.toLocaleString("en-US", { maximumFractionDigits: 0 });

/**
 * Revisa un lote antes de guardarlo. Las entregas que no cumplen las reglas
 * lo rechazan (`rechazos`); el resto son avisos que se guardan con el lote.
 */
export function evaluarLote(
  lote: LoteNuevo,
  candidatas: EntregaCandidata[],
): { rechazos: Rechazo[]; avisos: Aviso[]; kgEsperados: number } {
  const porId = new Map(candidatas.map((c) => [c.id, c]));
  const rechazos: Rechazo[] = [];
  const elegidas: EntregaCandidata[] = [];
  for (const id of lote.entregas) {
    const e = porId.get(id);
    const motivo = e ? motivoExclusion(e, lote.cultivo, lote.temporadaId) : "No existe o es de otra organización";
    if (motivo) rechazos.push({ entregaId: id, motivo });
    else elegidas.push(e!);
  }

  const c = cultivo(lote.cultivo)!;
  const nombreEstado = c.estados.find((x) => x.id === lote.estado)!.nombre.toLowerCase();
  const kgEsperados = elegidas.reduce((s, e) => s + convertirKg(c.id, e.kg, e.estado, lote.estado), 0);
  const avisos: Aviso[] = [];
  if (elegidas.length > 0 && lote.kg > kgEsperados * (1 + TOLERANCIA_VOLUMEN)) {
    avisos.push({
      codigo: "volumen",
      mensaje:
        `El lote pesa ${kg(lote.kg)} kg, pero sus entregas rinden unos ${kg(kgEsperados)} kg de ${nombreEstado}. ` +
        "Revisa que no se haya mezclado producto de fincas sin registrar.",
    });
  }

  const exportable = c.estados.find((x) => x.factorExportable === 1)!;
  const fincas = new Map(elegidas.map((e) => [e.fincaId, e]));
  for (const f of fincas.values()) {
    if (f.areaOficialHa <= 0) continue;
    const porHa = f.kgExportablesFincaTemporada / f.areaOficialHa;
    if (porHa > c.maxKgExportableHa) {
      avisos.push({
        codigo: "rendimiento",
        mensaje:
          `${f.fincaNombre}: sus entregas de la temporada equivalen a ${kg(porHa)} kg de ${exportable.nombre.toLowerCase()} por hectárea, ` +
          `más de lo razonable (${kg(c.maxKgExportableHa)} kg/ha). Puede haber producto de otra finca.`,
      });
    }
  }

  const sinVerde = [...fincas.values()].filter((f) => f.deforestacion !== "verde");
  if (sinVerde.length > 0) {
    avisos.push({
      codigo: "satelite",
      mensaje:
        `${sinVerde.length} de ${fincas.size} ${fincas.size === 1 ? "finca" : "fincas"} aún sin chequeo satelital verde ` +
        "(pendiente o con posible pérdida de bosque). El paquete EUDR lo va a pedir.",
    });
  }
  return { rechazos, avisos, kgEsperados };
}
