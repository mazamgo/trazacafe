-- TRACES rechaza geometrías inválidas (linderos que se cruzan, espinas).
-- La app y la API ya las rechazan; esto es la última barrera en la base.
ALTER TABLE fincas ADD CONSTRAINT geom_valida CHECK (ST_IsValid(geom));
