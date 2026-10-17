-- Lotes del beneficio o centro de acopio: agrupan entregas de un mismo
-- cultivo y temporada (Fase 2). Las tablas existían desde 001 sin usarse
-- (vacías), así que se completan aquí.

ALTER TABLE lotes
  ADD COLUMN codigo        text,
  ADD COLUMN cultivo       text CHECK (cultivo ~ '^[a-z_]+$'),
  ADD COLUMN temporada_id  uuid REFERENCES temporadas(id),
  -- Estado del producto del lote (p. ej. pergamino u oro; cacao seco).
  ADD COLUMN estado        text CHECK (estado ~ '^[a-z_]+$'),
  -- Kg que deberían rendir las entregas en ese estado, calculado al crearlo.
  ADD COLUMN kg_esperados  numeric(12, 2),
  -- Avisos al crearlo (volumen, rendimiento por ha, chequeo satelital):
  -- [{ "codigo": "...", "mensaje": "..." }]. No impiden crear el lote.
  ADD COLUMN avisos        jsonb NOT NULL DEFAULT '[]',
  ADD COLUMN creado_por    text;

ALTER TABLE lotes
  ALTER COLUMN codigo SET NOT NULL,
  ALTER COLUMN cultivo SET NOT NULL,
  ALTER COLUMN temporada_id SET NOT NULL,
  ALTER COLUMN estado SET NOT NULL,
  ALTER COLUMN kg_esperados SET NOT NULL,
  ALTER COLUMN creado_por SET NOT NULL,
  -- El proceso (lavado, natural, honey...) es opcional.
  ALTER COLUMN proceso DROP NOT NULL,
  ADD CONSTRAINT lotes_kg_positivo CHECK (kg > 0),
  ADD CONSTRAINT lotes_codigo_unico UNIQUE (organizacion_id, codigo);

CREATE INDEX lotes_organizacion_idx ON lotes (organizacion_id, creado_en DESC);

-- Una entrega va a un solo lote (también si dos personas arman lotes a la vez).
ALTER TABLE lote_entregas ADD CONSTRAINT lote_entregas_entrega_unica UNIQUE (entrega_id);
