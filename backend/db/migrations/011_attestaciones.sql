-- Attestations en la blockchain (Fase 2): registro de lo firmado y chequeos
-- satelitales atestables (esquema Chequeo).

-- Cada attestation firmada, para auditoría y para enlazar al explorador.
-- entidad_id es texto porque los chequeos tienen id numérico.
CREATE TABLE attestaciones (
  uid         text PRIMARY KEY,
  esquema     text NOT NULL,
  entidad_id  text NOT NULL,
  version     int NOT NULL DEFAULT 1,
  red         text NOT NULL,
  tx_hash     text NOT NULL,
  creado_en   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX attestaciones_entidad_idx ON attestaciones (esquema, entidad_id);

-- Cada chequeo satelital se atesta (resultado, fuente, fecha). Si se repite
-- el chequeo de la misma temporada y versión, el nuevo vuelve a atestarse.
ALTER TABLE chequeos_deforestacion ADD COLUMN attestation_uid text;

-- Reintentos del worker: no insistir con lo que acaba de fallar.
ALTER TABLE attestations_pendientes ADD COLUMN ultimo_intento timestamptz;
