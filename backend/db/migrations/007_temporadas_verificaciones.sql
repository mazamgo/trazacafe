-- Temporadas de cosecha, historial del lindero, visitas de verificación por
-- temporada y chequeos satelitales de deforestación.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Cada organización define sus temporadas (cosecha de café o cacao).
CREATE TABLE temporadas (
  id               uuid PRIMARY KEY,
  organizacion_id  uuid NOT NULL REFERENCES organizaciones(id),
  nombre           text NOT NULL,
  inicio           date NOT NULL,
  fin              date NOT NULL,
  creado_por       text NOT NULL,
  creado_en        timestamptz NOT NULL DEFAULT now(),
  CHECK (inicio < fin),
  -- Dos temporadas de la misma organización no pueden traslaparse.
  CONSTRAINT temporadas_sin_traslape
    EXCLUDE USING gist (organizacion_id WITH =, daterange(inicio, fin, '[]') WITH &&)
);

-- La API la asigna por la fecha de la entrega. Queda vacía si la
-- organización aún no creó esa temporada; se completa al crearla.
ALTER TABLE entregas ADD COLUMN temporada_id uuid REFERENCES temporadas(id);
CREATE INDEX entregas_temporada_idx ON entregas (temporada_id);

-- Historial del lindero: nunca se sobrescribe; `fincas` guarda la vigente.
CREATE TABLE fincas_versiones (
  finca_id         uuid NOT NULL REFERENCES fincas(id),
  version          int NOT NULL CHECK (version >= 1),
  geom             geometry(Geometry, 4326) NOT NULL CHECK (ST_IsValid(geom)),
  area_ha          numeric(10, 4) NOT NULL,
  area_oficial_ha  numeric(10, 4)
    GENERATED ALWAYS AS (round((ST_Area(geom::geography) / 10000)::numeric, 4)) STORED,
  geo_hash         text NOT NULL,
  attestation_uid  text,
  creado_por       text NOT NULL,
  creado_en        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (finca_id, version),
  CONSTRAINT version_punto_solo_menor_4ha CHECK (GeometryType(geom) <> 'POINT' OR area_ha < 4)
);

ALTER TABLE fincas ADD COLUMN version_actual int NOT NULL DEFAULT 1;

INSERT INTO fincas_versiones (finca_id, version, geom, area_ha, geo_hash, attestation_uid, creado_por, creado_en)
SELECT id, 1, geom, area_ha, geo_hash, attestation_uid, creado_por, creado_en FROM fincas;

-- Visita de verificación (fotos nuevas y, si cambió, una versión nueva del
-- lindero). La finca está verificada en una temporada si tiene al menos
-- una; se permiten varias (p. ej. volver después de una alerta).
CREATE TABLE verificaciones (
  id             uuid PRIMARY KEY,
  finca_id       uuid NOT NULL REFERENCES fincas(id),
  temporada_id   uuid REFERENCES temporadas(id),
  fecha          timestamptz NOT NULL,
  lindero_cambio boolean NOT NULL DEFAULT false,
  -- Versión del lindero vigente al terminar la visita.
  version_finca  int NOT NULL,
  nota           text,
  attestation_uid text,
  creado_por     text NOT NULL,
  creado_en      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX verificaciones_finca_idx ON verificaciones (finca_id, temporada_id);

ALTER TABLE fotos DROP CONSTRAINT fotos_entidad_tipo_check;
ALTER TABLE fotos ADD CONSTRAINT fotos_entidad_tipo_check
  CHECK (entidad_tipo IN ('productor', 'finca', 'verificacion'));
ALTER TABLE fotos DROP CONSTRAINT fotos_tipo_check;
ALTER TABLE fotos ADD CONSTRAINT fotos_tipo_check
  CHECK (tipo IN ('consentimiento', 'finca', 'documento', 'verificacion'));

-- Chequeo satelital (Global Forest Watch) de una versión del lindero en una
-- temporada. `fincas.deforestacion` guarda el último resultado.
CREATE TABLE chequeos_deforestacion (
  id                bigserial PRIMARY KEY,
  finca_id          uuid NOT NULL REFERENCES fincas(id),
  temporada_id      uuid REFERENCES temporadas(id),
  version_finca     int NOT NULL,
  fecha             timestamptz NOT NULL DEFAULT now(),
  fuente            text NOT NULL,
  alertas           int NOT NULL,
  area_afectada_ha  numeric(10, 4) NOT NULL,
  resultado         estado_deforestacion NOT NULL,
  detalle           jsonb NOT NULL DEFAULT '{}',
  UNIQUE (finca_id, temporada_id, version_finca)
);

-- Cola de attestations: cada versión del lindero y cada visita se atestan.
ALTER TABLE attestations_pendientes DROP CONSTRAINT attestations_pendientes_esquema_check;
ALTER TABLE attestations_pendientes ADD CONSTRAINT attestations_pendientes_esquema_check
  CHECK (esquema IN ('Finca', 'Entrega', 'Lote', 'Exportacion', 'Verificacion'));
ALTER TABLE attestations_pendientes ADD COLUMN version int NOT NULL DEFAULT 1;
ALTER TABLE attestations_pendientes DROP CONSTRAINT attestations_pendientes_esquema_entidad_id_key;
ALTER TABLE attestations_pendientes ADD CONSTRAINT attestations_pendientes_unica
  UNIQUE (esquema, entidad_id, version);
