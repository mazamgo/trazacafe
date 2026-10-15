-- Esquema inicial de TrazaCafé (Cloud SQL for PostgreSQL + PostGIS)

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE cooperativas (
  id              uuid PRIMARY KEY,
  nombre          text NOT NULL,
  -- Dirección que firma sus attestations (clave en Cloud KMS o Safe)
  atestador       text,
  creado_en       timestamptz NOT NULL DEFAULT now()
);

-- Datos personales: NUNCA salen a la blockchain (Ley 787)
CREATE TABLE productores (
  id                     uuid PRIMARY KEY,
  cooperativa_id         uuid NOT NULL REFERENCES cooperativas(id),
  nombre                 text NOT NULL,
  cedula                 text,
  comunidad              text,
  consentimiento_firmado boolean NOT NULL DEFAULT false,
  creado_en              timestamptz NOT NULL DEFAULT now()
);

CREATE TYPE estado_deforestacion AS ENUM ('pendiente', 'verde', 'amarillo', 'rojo');

CREATE TABLE fincas (
  id                    uuid PRIMARY KEY,
  productor_id          uuid NOT NULL REFERENCES productores(id),
  nombre                text NOT NULL,
  -- Punto (< 4 ha) o polígono (>= 4 ha), WGS84
  geom                  geometry(Geometry, 4326) NOT NULL,
  area_ha               numeric(10, 4) NOT NULL,
  geo_hash              text NOT NULL,
  deforestacion         estado_deforestacion NOT NULL DEFAULT 'pendiente',
  attestation_uid       text,
  creado_en             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT punto_solo_menor_4ha
    CHECK (GeometryType(geom) <> 'POINT' OR area_ha < 4)
);
CREATE INDEX fincas_geom_idx ON fincas USING gist (geom);

CREATE TABLE entregas (
  id               uuid PRIMARY KEY,
  finca_id         uuid NOT NULL REFERENCES fincas(id),
  kg               numeric(10, 2) NOT NULL CHECK (kg > 0),
  estado           text NOT NULL CHECK (estado IN ('uva', 'pergamino')),
  fecha            timestamptz NOT NULL,
  attestation_uid  text
);

CREATE TABLE lotes (
  id               uuid PRIMARY KEY,
  cooperativa_id   uuid NOT NULL REFERENCES cooperativas(id),
  kg               numeric(10, 2) NOT NULL,
  beneficio        text NOT NULL,
  proceso          text NOT NULL,
  attestation_uid  text,
  creado_en        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE lote_entregas (
  lote_id     uuid NOT NULL REFERENCES lotes(id),
  entrega_id  uuid NOT NULL REFERENCES entregas(id),
  PRIMARY KEY (lote_id, entrega_id)
);

CREATE TABLE exportaciones (
  id               uuid PRIMARY KEY,
  cooperativa_id   uuid NOT NULL REFERENCES cooperativas(id),
  contenedor       text NOT NULL,
  destino          text NOT NULL,
  dds_ref          text,
  attestation_uid  text,
  creado_en        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE exportacion_lotes (
  exportacion_id  uuid NOT NULL REFERENCES exportaciones(id),
  lote_id         uuid NOT NULL REFERENCES lotes(id),
  PRIMARY KEY (exportacion_id, lote_id)
);

-- Cola que el worker procesa en lote con multiAttest
CREATE TABLE attestations_pendientes (
  id           bigserial PRIMARY KEY,
  esquema      text NOT NULL CHECK (esquema IN ('Finca', 'Entrega', 'Lote', 'Exportacion')),
  entidad_id   uuid NOT NULL,
  intentos     int NOT NULL DEFAULT 0,
  error        text,
  creado_en    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (esquema, entidad_id)
);
