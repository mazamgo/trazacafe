-- Notificaciones push (FCM): el celular de cada persona registra su token al
-- entrar. Los avisos van solo a los administradores de la organización.
CREATE TABLE dispositivos (
  token            text PRIMARY KEY,
  usuario_uid      text NOT NULL,
  organizacion_id  uuid NOT NULL REFERENCES organizaciones(id) ON DELETE CASCADE,
  plataforma       text NOT NULL DEFAULT 'android',
  actualizado_en   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX dispositivos_organizacion_idx ON dispositivos (organizacion_id);
