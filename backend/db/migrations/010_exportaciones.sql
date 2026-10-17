-- Contenedores de exportación: agrupan lotes de un mismo cultivo (Fase 2).
-- Las tablas existían desde 001 sin usarse (vacías), así que se completan aquí.

ALTER TABLE exportaciones
  ADD COLUMN codigo          text,
  ADD COLUMN cultivo         text CHECK (cultivo ~ '^[a-z_]+$'),
  ADD COLUMN comprador       text,
  ADD COLUMN fecha_embarque  date,
  -- abierta: se puede editar o deshacer; cerrada: lista para el paquete EUDR
  -- y su attestation (se cierra en el paso del paquete EUDR).
  ADD COLUMN estado          text NOT NULL DEFAULT 'abierta' CHECK (estado IN ('abierta', 'cerrada')),
  ADD COLUMN creado_por      text;

ALTER TABLE exportaciones
  ALTER COLUMN codigo SET NOT NULL,
  ALTER COLUMN cultivo SET NOT NULL,
  ALTER COLUMN comprador SET NOT NULL,
  ALTER COLUMN creado_por SET NOT NULL,
  -- El número del contenedor (ISO 6346) suele conocerse tarde.
  ALTER COLUMN contenedor DROP NOT NULL,
  ADD CONSTRAINT exportaciones_codigo_unico UNIQUE (organizacion_id, codigo);

CREATE INDEX exportaciones_organizacion_idx ON exportaciones (organizacion_id, creado_en DESC);

-- Un lote va a un solo contenedor.
ALTER TABLE exportacion_lotes ADD CONSTRAINT exportacion_lotes_lote_unico UNIQUE (lote_id);
