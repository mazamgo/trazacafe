-- Fotos de campo: consentimiento firmado, finca, documentos.
-- El hash sha256 entra en docsHash de la attestation de la finca; el archivo
-- se guardará en Cloud Storage (storage_path) cuando se suba.

CREATE TABLE fotos (
  id              uuid PRIMARY KEY,
  cooperativa_id  uuid NOT NULL REFERENCES cooperativas(id),
  entidad_tipo    text NOT NULL CHECK (entidad_tipo IN ('productor', 'finca')),
  entidad_id      uuid NOT NULL,
  tipo            text NOT NULL CHECK (tipo IN ('consentimiento', 'finca', 'documento')),
  sha256          text NOT NULL,
  storage_path    text,
  creado_en       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX fotos_entidad_idx ON fotos (entidad_tipo, entidad_id);
