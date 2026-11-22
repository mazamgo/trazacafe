-- Visitas de control de la exportadora (Fase 2b, paso 5): con permiso de la
-- cooperativa, la exportadora elige fincas de los lotes que le vendieron y
-- sus técnicos las visitan. Esas visitas no cuentan como la visita de
-- verificación de la cooperativa (la que exige un lote).

ALTER TABLE vinculos ADD COLUMN permite_visitas boolean NOT NULL DEFAULT false;

-- Fincas elegidas por la exportadora para visitar, por temporada de sus lotes.
CREATE TABLE muestreos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vinculo_id    uuid NOT NULL REFERENCES vinculos(id),
  finca_id      uuid NOT NULL REFERENCES fincas(id) ON DELETE CASCADE,
  temporada_id  uuid NOT NULL REFERENCES temporadas(id),
  asignado_por  text NOT NULL,
  asignado_en   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (vinculo_id, finca_id, temporada_id)
);

-- `NULL` = visita propia de la organización de la finca; si no, la
-- exportadora que hizo la visita de control.
ALTER TABLE verificaciones ADD COLUMN organizacion_id uuid REFERENCES organizaciones(id);
