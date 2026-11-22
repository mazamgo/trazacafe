-- Consola del propietario (GoProduction): suspender organizaciones por falta
-- de pago, ver cada corrida de las tareas programadas y registrar cada
-- acción de la consola.

-- Suspendida: la API no acepta datos nuevos de la organización, pero ella
-- sigue viendo y descargando lo suyo (y el verificador sigue funcionando).
ALTER TABLE organizaciones ADD COLUMN suspendida_en timestamptz;

-- Cada corrida de una tarea programada (chequeo, attestations, eliminaciones).
CREATE TABLE corridas_tareas (
  id         bigserial PRIMARY KEY,
  tarea      text NOT NULL,
  inicio     timestamptz NOT NULL,
  fin        timestamptz NOT NULL DEFAULT now(),
  ok         boolean NOT NULL,
  detalle    jsonb NOT NULL DEFAULT '{}'
);
CREATE INDEX corridas_tareas_tarea_idx ON corridas_tareas (tarea, inicio DESC);

-- Lo que hace el propietario en la consola.
CREATE TABLE historial_consola (
  id               bigserial PRIMARY KEY,
  usuario_uid      text NOT NULL,
  email            text NOT NULL,
  accion           text NOT NULL,
  organizacion_id  uuid REFERENCES organizaciones(id),
  detalle          jsonb NOT NULL DEFAULT '{}',
  creado_en        timestamptz NOT NULL DEFAULT now()
);
