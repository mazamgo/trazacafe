import { createHash } from "node:crypto";

/**
 * Archivos de fotos en Cloud Storage. La app los sube directo (las reglas de
 * Storage solo dejan escribir en la carpeta de su organización) y la API
 * comprueba que el contenido coincide con el hash que llegó al sincronizar.
 */
export interface Almacen {
  /** Contenido del archivo, o `null` si no existe. */
  leer(ruta: string): Promise<Buffer | null>;
  borrar(ruta: string): Promise<void>;
}

/** Ruta de una foto en Storage. La app usa la misma (lib/services/fotos_service.dart). */
export function rutaFoto(organizacionId: string, fotoId: string): string {
  return `organizaciones/${organizacionId}/fotos/${fotoId}.jpg`;
}

export function sha256Hex(datos: Buffer): string {
  return `0x${createHash("sha256").update(datos).digest("hex")}`;
}
