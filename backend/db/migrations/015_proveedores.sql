-- Red de proveedores (Fase 2b): la exportadora recibe lotes de las
-- cooperativas que le venden y arma contenedores con ellos. Detalle en
-- docs/plan-nicaragua-multicultivo.md (Fase 2b).

-- Vínculo entre una proveedora (cooperativa) y su cliente (exportadora). La
-- exportadora invita; la cooperativa acepta y elige si comparte los nombres
-- de los productores (Ley 787). Siempre se comparte lo que pide el EUDR:
-- ubicación, área, estado satelital, visitas y attestations.
CREATE TABLE vinculos (
  id                uuid PRIMARY KEY,
  proveedora_id     uuid NOT NULL REFERENCES organizaciones(id),
  cliente_id        uuid NOT NULL REFERENCES organizaciones(id),
  estado            text NOT NULL DEFAULT 'pendiente'
                    CHECK (estado IN ('pendiente', 'activo', 'rechazado', 'terminado')),
  comparte_nombres  boolean NOT NULL DEFAULT false,
  invitado_por      text NOT NULL,
  invitado_en       timestamptz NOT NULL DEFAULT now(),
  respondido_por    text,
  respondido_en     timestamptz,
  terminado_por     text,
  terminado_en      timestamptz,
  CHECK (proveedora_id <> cliente_id)
);

-- Un solo vínculo vigente (pendiente o activo) por pareja.
CREATE UNIQUE INDEX vinculos_vigente_unico ON vinculos (proveedora_id, cliente_id)
  WHERE estado IN ('pendiente', 'activo');
CREATE INDEX vinculos_cliente_idx ON vinculos (cliente_id);

-- Venta de un lote a la exportadora. El lote sigue siendo de la cooperativa
-- (su historial y su attestation) y pasa al inventario de la exportadora al
-- recibirlo. Un lote se vende una sola vez; la venta se deshace (se borra la
-- fila) mientras el lote no esté en un contenedor.
CREATE TABLE ventas_lotes (
  lote_id        uuid PRIMARY KEY REFERENCES lotes(id),
  vinculo_id     uuid NOT NULL REFERENCES vinculos(id),
  cliente_id     uuid NOT NULL REFERENCES organizaciones(id),
  kg_enviados    numeric(12, 2) NOT NULL CHECK (kg_enviados > 0),
  fecha_envio    date NOT NULL,
  vendido_por    text NOT NULL,
  vendido_en     timestamptz NOT NULL DEFAULT now(),
  estado         text NOT NULL DEFAULT 'enviado' CHECK (estado IN ('enviado', 'recibido')),
  -- Lo que pesó la exportadora al recibir: es lo que cuenta en el contenedor.
  kg_recibidos   numeric(12, 2) CHECK (kg_recibidos > 0),
  fecha_recibido date,
  recibido_por   text,
  CHECK (estado = 'enviado' OR (kg_recibidos IS NOT NULL AND fecha_recibido IS NOT NULL AND recibido_por IS NOT NULL))
);

CREATE INDEX ventas_lotes_cliente_idx ON ventas_lotes (cliente_id, estado);

-- Observaciones de la exportadora sobre una finca o un lote de un proveedor
-- ("revisar el lindero de la Finca 3"); la cooperativa las responde. La
-- exportadora no corrige datos de la cooperativa.
CREATE TABLE observaciones (
  id              uuid PRIMARY KEY,
  cliente_id      uuid NOT NULL REFERENCES organizaciones(id),
  proveedora_id   uuid NOT NULL REFERENCES organizaciones(id),
  finca_id        uuid REFERENCES fincas(id) ON DELETE CASCADE,
  lote_id         uuid REFERENCES lotes(id) ON DELETE CASCADE,
  texto           text NOT NULL CHECK (length(texto) BETWEEN 3 AND 1000),
  creado_por      text NOT NULL,
  creado_en       timestamptz NOT NULL DEFAULT now(),
  respuesta       text CHECK (length(respuesta) BETWEEN 1 AND 1000),
  respondido_por  text,
  respondido_en   timestamptz,
  CHECK ((finca_id IS NULL) <> (lote_id IS NULL))
);

CREATE INDEX observaciones_cliente_idx ON observaciones (cliente_id, creado_en DESC);
CREATE INDEX observaciones_proveedora_idx ON observaciones (proveedora_id, creado_en DESC);

-- Kg con que un lote cuenta dentro de un contenedor: los recibidos por la
-- exportadora si lo compró, o los del lote si es propio. Lo usan igual la
-- attestation `Exportacion`, el verificador, la pantalla y el cobro, para
-- que la firma y lo que se muestra coincidan.
CREATE FUNCTION kg_en_contenedor(lote uuid) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT coalesce(
    (SELECT v.kg_recibidos FROM ventas_lotes v WHERE v.lote_id = lote AND v.estado = 'recibido'),
    (SELECT l.kg FROM lotes l WHERE l.id = lote))
$$;
