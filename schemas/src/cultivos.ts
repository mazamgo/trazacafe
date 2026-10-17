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
  estados: { id: string; nombre: string; corto: string }[];
  maxKgEntrega: number;
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

/** Todos los estados de todos los cultivos (para validar el formato antes de saber la finca). */
export const TODOS_LOS_ESTADOS = [...new Set(cultivos.flatMap((c) => c.estados.map((e) => e.id)))];
