import definiciones from "../cultivos.json" with { type: "json" };

/**
 * Cultivos que maneja la plataforma (EUDR). Agregar uno nuevo es agregarlo a
 * cultivos.json y regenerar la versión de la app: `npm run cultivos-dart`.
 */
export type IdCultivo = keyof typeof definiciones;

export interface Cultivo {
  id: IdCultivo;
  nombre: string;
  /** Código del Sistema Armonizado que pide la DDS de TRACES. */
  codigoHS: string;
  color: string;
  /**
   * `factorExportable`: kg del producto que se exporta (café oro, cacao seco)
   * que rinde 1 kg en ese estado. Aproximaciones para el control de volumen
   * de los lotes; se ajustan con datos del piloto.
   */
  estados: { id: string; nombre: string; corto: string; factorExportable: number }[];
  maxKgEntrega: number;
  /** Rendimiento máximo razonable por temporada, en kg exportables por hectárea. */
  maxKgExportableHa: number;
}

export const cultivos: Cultivo[] = (Object.keys(definiciones) as IdCultivo[]).map((id) => ({
  id,
  ...definiciones[id],
}));

export const ID_CULTIVOS = cultivos.map((c) => c.id) as [IdCultivo, ...IdCultivo[]];

export function cultivo(id: string): Cultivo | undefined {
  return cultivos.find((c) => c.id === id);
}

/** ¿Ese estado de entrega existe para ese cultivo? (p. ej. "baba" solo en cacao). */
export function estadoValido(idCultivo: string, estado: string): boolean {
  return cultivo(idCultivo)?.estados.some((e) => e.id === estado) ?? false;
}

/** Factor de [estado] en [idCultivo]; lanza si no existe (validar antes con estadoValido). */
export function factorExportable(idCultivo: string, estado: string): number {
  const e = cultivo(idCultivo)?.estados.find((x) => x.id === estado);
  if (!e) throw new Error(`Estado ${estado} no existe en ${idCultivo}`);
  return e.factorExportable;
}

/**
 * Kg en [estadoDestino] que rinden unas entregas: p. ej. 500 kg de uva rinden
 * unos 100 kg de pergamino (500 × 0.16 / 0.8).
 */
export function convertirKg(idCultivo: string, kg: number, estadoOrigen: string, estadoDestino: string): number {
  return (kg * factorExportable(idCultivo, estadoOrigen)) / factorExportable(idCultivo, estadoDestino);
}

/** Todos los estados de todos los cultivos (para validar el formato antes de saber la finca). */
export const TODOS_LOS_ESTADOS = [...new Set(cultivos.flatMap((c) => c.estados.map((e) => e.id)))];
