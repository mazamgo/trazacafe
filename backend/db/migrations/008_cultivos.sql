-- Varios cultivos (café, cacao; la lista está en schemas/cultivos.json y la
-- API valida qué estados de entrega admite cada uno).

-- Cultivos con los que trabaja cada organización.
ALTER TABLE organizaciones ADD COLUMN cultivos text[] NOT NULL DEFAULT ARRAY['cafe'];

-- El cultivo es un dato de la finca y no cambia; las fincas existentes son café.
ALTER TABLE fincas ADD COLUMN cultivo text NOT NULL DEFAULT 'cafe' CHECK (cultivo ~ '^[a-z_]+$');

-- Una temporada puede ser de un cultivo (p. ej. la cosecha principal de
-- cacao) o, si está vacío, de todos. Solo no se traslapan las del mismo cultivo.
ALTER TABLE temporadas ADD COLUMN cultivo text CHECK (cultivo IS NULL OR cultivo ~ '^[a-z_]+$');
ALTER TABLE temporadas DROP CONSTRAINT temporadas_sin_traslape;
ALTER TABLE temporadas ADD CONSTRAINT temporadas_sin_traslape
  EXCLUDE USING gist (
    organizacion_id WITH =,
    (coalesce(cultivo, '*')) WITH =,
    daterange(inicio, fin, '[]') WITH &&
  );

-- Los estados de entrega ya no son solo de café (uva, pergamino): los valida
-- la API según el cultivo de la finca.
ALTER TABLE entregas DROP CONSTRAINT entregas_estado_check;
ALTER TABLE entregas ADD CONSTRAINT entregas_estado_check CHECK (estado ~ '^[a-z_]+$');
