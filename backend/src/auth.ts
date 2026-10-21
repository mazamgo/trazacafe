export type Rol = "admin" | "tecnico";

/** Persona con sesión de Google válida; puede no tener acceso todavía. */
export interface Usuario {
  uid: string;
  email: string;
  /** Vienen del custom claim; faltan hasta que se activa una invitación. */
  organizacionId?: string;
  rol?: Rol;
}

/** Usuario que ya activó su invitación. */
export interface UsuarioActivo extends Usuario {
  organizacionId: string;
  rol: Rol;
}

export function estaActivo(u: Usuario): u is UsuarioActivo {
  return typeof u.organizacionId === "string" && (u.rol === "admin" || u.rol === "tecnico");
}

/** Valida el token de Firebase; `null` si es inválido, venció o fue revocado. */
export type VerificarToken = (token: string) => Promise<Usuario | null>;

/** Operaciones sobre las cuentas de Firebase. */
export interface Identidad {
  /** Guarda organización y rol en el token (custom claims). */
  asignarAcceso(uid: string, acceso: { organizacionId: string; rol: Rol }): Promise<void>;
  /** Borra los claims y cierra todas las sesiones abiertas de esa persona. */
  quitarAcceso(uid: string): Promise<void>;
  /** Borra la cuenta de Firebase Auth (si ya no existe, no es error). */
  eliminarUsuario(uid: string): Promise<void>;
}
