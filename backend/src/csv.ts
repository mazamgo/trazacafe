/** CSV para Excel y plataformas externas: BOM (tildes) y fin de línea de Windows. */

/** Un campo: entre comillas si lleva coma, comillas o salto de línea. */
export function campoCsv(v: string | number | null | undefined): string {
  const s = v === null || v === undefined ? "" : String(v);
  return /[",\r\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
}

export function csv(filas: (string | number | null | undefined)[][]): string {
  return `﻿${filas.map((f) => f.map(campoCsv).join(",")).join("\r\n")}\r\n`;
}
