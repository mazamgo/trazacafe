-- Área oficial de la finca: la calcula PostGIS sobre el elipsoide WGS84,
-- más precisa que la de la app (esfera, como Turf). Es la que va al paquete
-- EUDR. Al ser columna generada, siempre corresponde a la geometría guardada.
ALTER TABLE fincas
  ADD COLUMN area_oficial_ha numeric(10, 4)
  GENERATED ALWAYS AS (round((ST_Area(geom::geography) / 10000)::numeric, 4)) STORED;

-- Cuándo llegó cada entrega al servidor (la fecha de la entrega es otra).
ALTER TABLE entregas ADD COLUMN creado_en timestamptz NOT NULL DEFAULT now();
CREATE INDEX entregas_finca_idx ON entregas (finca_id);
