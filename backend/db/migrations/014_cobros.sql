-- Base del cobro (Fase 4): contratos por organización y registro de lo que
-- se cobra. Detalle en docs/plan-nicaragua-multicultivo.md (Fase 3, "Cobro
-- por contenedor").

-- Lo acordado con cada organización para un período (normalmente una
-- temporada). Los montos son hipótesis hasta validarlos con el piloto: el
-- modelo admite cuota fija, solo por contenedor o ambos.
CREATE TABLE contratos (
  id                      uuid PRIMARY KEY,
  organizacion_id         uuid NOT NULL REFERENCES organizaciones(id),
  plan                    text NOT NULL CHECK (plan IN ('basico', 'exportador', 'comprador')),
  inicio                  date NOT NULL,
  fin                     date NOT NULL,
  -- Cuota del período, pagada por adelantado (0 si solo se cobra por uso).
  cuota_usd               numeric(12, 2) NOT NULL DEFAULT 0 CHECK (cuota_usd >= 0),
  -- Contenedores incluidos en la cuota (la "bolsa").
  contenedores_incluidos  int NOT NULL DEFAULT 0 CHECK (contenedores_incluidos >= 0),
  -- Precio de cada contenedor cerrado después de agotar la bolsa.
  precio_contenedor_usd   numeric(12, 2) NOT NULL DEFAULT 0 CHECK (precio_contenedor_usd >= 0),
  estado                  text NOT NULL DEFAULT 'prueba'
                          CHECK (estado IN ('prueba', 'activo', 'en_mora', 'suspendido')),
  nota                    text,
  creado_por              text NOT NULL,
  creado_en               timestamptz NOT NULL DEFAULT now(),
  CHECK (inicio < fin),
  -- Una organización tiene un solo contrato vigente a la vez.
  CONSTRAINT contratos_sin_traslape
    EXCLUDE USING gist (organizacion_id WITH =, daterange(inicio, fin, '[]') WITH &&)
);

-- Una fila por cada cosa que se cobra. No se cambia ni se borra: un ajuste
-- (cortesía, error) es otra fila con monto negativo y motivo. Así un mes ya
-- facturado no cambia aunque cambie el contrato.
CREATE TABLE consumos (
  id                 uuid PRIMARY KEY,
  organizacion_id    uuid NOT NULL REFERENCES organizaciones(id),
  tipo               text NOT NULL CHECK (tipo IN ('contenedor', 'ajuste')),
  fecha              timestamptz NOT NULL DEFAULT now(),
  -- Contrato vigente al registrarlo (NULL si la organización no tenía).
  contrato_id        uuid REFERENCES contratos(id),
  -- Contenedor cerrado: se copian sus datos (sin llave foránea: el cobro se
  -- conserva aunque el contenedor se depure al eliminar la organización).
  exportacion_id     uuid,
  codigo             text,
  numero_contenedor  text,
  cultivo            text,
  kg                 numeric(12, 2),
  -- Precio por contenedor adicional del contrato, congelado al cerrar.
  precio_usd         numeric(12, 2),
  -- Ajuste: monto (negativo = descuento) y motivo.
  monto_usd          numeric(12, 2),
  motivo             text,
  -- Attestation `Exportacion`: la agrega el worker cuando la firma (necesita
  -- la referencia de la DDS), para revisar cada contenedor cobrado.
  attestation_uid    text,
  creado_por         text NOT NULL,
  CHECK (tipo <> 'contenedor' OR (exportacion_id IS NOT NULL AND codigo IS NOT NULL)),
  CHECK (tipo <> 'ajuste' OR (monto_usd IS NOT NULL AND monto_usd <> 0 AND motivo IS NOT NULL AND exportacion_id IS NULL))
);

-- Un contenedor se cobra una sola vez.
CREATE UNIQUE INDEX consumos_contenedor_unico ON consumos (exportacion_id) WHERE tipo = 'contenedor';
CREATE INDEX consumos_organizacion_fecha_idx ON consumos (organizacion_id, fecha);

-- Solo se permite completar la attestation (de vacía a su UID); nada más se
-- cambia ni se borra.
CREATE FUNCTION consumos_inmutables() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Los consumos no se borran: registra un ajuste.';
  END IF;
  IF OLD.attestation_uid IS NULL
     AND (to_jsonb(NEW) - 'attestation_uid') = (to_jsonb(OLD) - 'attestation_uid') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'Los consumos no se cambian: registra un ajuste.';
END;
$$;

CREATE TRIGGER consumos_inmutables
  BEFORE UPDATE OR DELETE ON consumos
  FOR EACH ROW EXECUTE FUNCTION consumos_inmutables();
