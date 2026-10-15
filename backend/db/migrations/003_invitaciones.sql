-- Acceso por invitación: cualquier cuenta de Google puede iniciar sesión,
-- pero solo los correos invitados reciben una organización y un rol.

CREATE TABLE invitaciones (
  -- Correo de Google en minúsculas; una persona pertenece a una organización
  email            text PRIMARY KEY CHECK (email = lower(email)),
  organizacion_id  uuid NOT NULL REFERENCES organizaciones(id),
  rol              text NOT NULL CHECK (rol IN ('admin', 'tecnico')),
  invitado_por     text NOT NULL,
  -- uid de Firebase cuando la persona activa su acceso
  usuario_uid      text UNIQUE,
  creado_en        timestamptz NOT NULL DEFAULT now(),
  aceptada_en      timestamptz
);
CREATE INDEX invitaciones_organizacion_idx ON invitaciones (organizacion_id);
