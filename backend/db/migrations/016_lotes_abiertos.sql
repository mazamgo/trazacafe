-- Lotes abiertos: el administrador crea el lote y le va sumando entregas hasta
-- cerrarlo. Solo el lote cerrado se firma, se vende o va en un contenedor.

-- `cerrado_en` vacío = abierto. La columna `estado` ya guarda el estado del
-- producto (pergamino, oro…).
ALTER TABLE lotes
  ADD COLUMN cerrado_en timestamptz,
  ADD COLUMN cerrado_por text;

-- Los lotes de antes ya estaban completos al crearse.
UPDATE lotes SET cerrado_en = creado_en, cerrado_por = creado_por;
