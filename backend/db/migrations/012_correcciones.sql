-- Correcciones de datos con errores (un cero de más, la fecha equivocada...)
-- mientras no estén sellados (en un lote o firmados en la blockchain).

-- Historial de cada corrección o anulación: qué cambió, quién y por qué.
CREATE TABLE correcciones (
  id               bigserial PRIMARY KEY,
  organizacion_id  uuid NOT NULL REFERENCES organizaciones(id),
  -- entrega, lote, productor, finca, foto, verificacion, temporada
  entidad          text NOT NULL,
  entidad_id       text NOT NULL,
  accion           text NOT NULL CHECK (accion IN ('corregir', 'anular', 'eliminar')),
  -- Solo los campos que cambiaron: { "kg": 5000 } → { "kg": 500 }
  antes            jsonb NOT NULL DEFAULT '{}',
  despues          jsonb NOT NULL DEFAULT '{}',
  motivo           text,
  usuario_uid      text NOT NULL,
  creado_en        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX correcciones_entidad_idx ON correcciones (entidad, entidad_id);
CREATE INDEX correcciones_organizacion_idx ON correcciones (organizacion_id, creado_en DESC);

-- Anular no borra: la entrega o visita queda en la base y en el historial,
-- pero deja de contar (listas, lotes, paquete EUDR, attestations).
ALTER TABLE entregas
  ADD COLUMN anulada_en        timestamptz,
  ADD COLUMN anulada_por       text,
  ADD COLUMN motivo_anulacion  text;
ALTER TABLE verificaciones
  ADD COLUMN anulada_en        timestamptz,
  ADD COLUMN anulada_por       text,
  ADD COLUMN motivo_anulacion  text;

CREATE INDEX entregas_vigentes_idx ON entregas (finca_id) WHERE anulada_en IS NULL;
CREATE INDEX verificaciones_vigentes_idx ON verificaciones (finca_id, temporada_id) WHERE anulada_en IS NULL;
