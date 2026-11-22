-- Portal del importador (Fase 2c, nivel básico + monitoreo): la exportadora
-- invita a su comprador de la UE, le asigna contenedores cerrados y él ve
-- solo esos contenedores, descarga su paquete EUDR, anota su DDS y recibe
-- alertas si una finca de origen pasa a amarillo o rojo después de la compra.

ALTER TABLE organizaciones DROP CONSTRAINT IF EXISTS organizaciones_tipo_check;
ALTER TABLE organizaciones ADD CONSTRAINT organizaciones_tipo_check
  CHECK (tipo IN ('cooperativa', 'exportadora', 'beneficio', 'otra', 'importador'));

-- Vínculo exportadora → importador. La exportadora invita; el importador acepta.
CREATE TABLE compradores (
  id              uuid PRIMARY KEY,
  exportadora_id  uuid NOT NULL REFERENCES organizaciones(id),
  importador_id   uuid NOT NULL REFERENCES organizaciones(id),
  estado          text NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN ('pendiente', 'activo', 'rechazado', 'terminado')),
  invitado_por    text NOT NULL,
  invitado_en     timestamptz NOT NULL DEFAULT now(),
  respondido_en   timestamptz,
  terminado_en    timestamptz,
  CHECK (exportadora_id <> importador_id)
);
CREATE UNIQUE INDEX compradores_vigente_unico ON compradores (exportadora_id, importador_id)
  WHERE estado IN ('pendiente', 'activo');

-- Contenedor cerrado asignado a su importador, con la referencia de su DDS.
CREATE TABLE ventas_contenedores (
  exportacion_id  uuid PRIMARY KEY REFERENCES exportaciones(id),
  comprador_id    uuid NOT NULL REFERENCES compradores(id),
  importador_id   uuid NOT NULL REFERENCES organizaciones(id),
  vendido_por     text NOT NULL,
  vendido_en      timestamptz NOT NULL DEFAULT now(),
  dds_ref         text,
  dds_en          timestamptz
);
CREATE INDEX ventas_contenedores_importador_idx ON ventas_contenedores (importador_id);

-- Monitoreo después de la compra: una finca de un contenedor vendido que pasa
-- a amarillo o rojo. `avisado_en` = cuándo se mandó el correo.
CREATE TABLE alertas_comprador (
  id              bigserial PRIMARY KEY,
  exportacion_id  uuid NOT NULL REFERENCES exportaciones(id),
  finca_id        uuid NOT NULL REFERENCES fincas(id) ON DELETE CASCADE,
  resultado       estado_deforestacion NOT NULL,
  detectada_en    timestamptz NOT NULL DEFAULT now(),
  avisado_en      timestamptz,
  UNIQUE (exportacion_id, finca_id, resultado)
);
