-- Eliminación de datos (Ley 787 y requisito de Google Play): productores
-- que piden borrar sus datos, cuentas del equipo y organizaciones completas.
-- Lo que el EUDR obliga a guardar (fincas con entregas en lotes, contenedores
-- o firmadas en la blockchain) se anonimiza y se conserva 5 años (art. 12).

-- Solicitudes que un productor envía desde la página web pública. Las
-- aprueba el administrador de su cooperativa. Al cerrarse, `datos` se vacía:
-- no se guarda la cédula de quien pidió que lo borraran.
CREATE TABLE solicitudes_eliminacion (
  id               uuid PRIMARY KEY,
  -- NULL si el productor no supo elegir su cooperativa: la atiende GoProduction.
  organizacion_id  uuid REFERENCES organizaciones(id),
  -- { nombre, cedula, comunidad, contacto, mensaje }
  datos            jsonb NOT NULL,
  estado           text NOT NULL DEFAULT 'pendiente'
                     CHECK (estado IN ('pendiente', 'ejecutada', 'rechazada')),
  productor_id     uuid,
  motivo_rechazo   text,
  resuelta_por     text,
  resuelta_en      timestamptz,
  creada_en        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX solicitudes_eliminacion_pendientes_idx
  ON solicitudes_eliminacion (organizacion_id, creada_en) WHERE estado = 'pendiente';

-- Ids de lo que se borró. La sincronización ignora lo que un celular
-- todavía tenía pendiente de esos registros, para no volver a crearlos.
CREATE TABLE eliminados (
  id               uuid PRIMARY KEY,
  entidad          text NOT NULL CHECK (entidad IN ('productor', 'finca', 'verificacion')),
  organizacion_id  uuid NOT NULL REFERENCES organizaciones(id),
  eliminado_en     timestamptz NOT NULL DEFAULT now()
);

-- Archivos de Storage por borrar: se encolan en la misma transacción que
-- borra el registro y la tarea diaria los borra con reintentos.
CREATE TABLE archivos_por_borrar (
  ruta       text PRIMARY KEY,
  intentos   int NOT NULL DEFAULT 0,
  creado_en  timestamptz NOT NULL DEFAULT now()
);

-- Anonimizado: sin nombre, cédula, comunidad ni fotos; se conserva hasta
-- `conservar_hasta` y después la tarea diaria lo borra.
ALTER TABLE productores
  ADD COLUMN anonimizado_en   timestamptz,
  ADD COLUMN conservar_hasta  date;
ALTER TABLE fincas
  ADD COLUMN anonimizada_en   timestamptz,
  ADD COLUMN conservar_hasta  date;
CREATE INDEX fincas_conservar_idx ON fincas (conservar_hasta) WHERE conservar_hasta IS NOT NULL;

-- La foto de un registro anonimizado se queda solo con su hash (que puede
-- estar en una attestation); el archivo se borra.
ALTER TABLE fotos ADD COLUMN archivo_borrado_en timestamptz;

-- Eliminación de la organización: se ejecuta 30 días después de pedirla,
-- salvo que el administrador la cancele. La fila queda (sin nombre) si hay
-- datos que conservar por el EUDR.
ALTER TABLE organizaciones
  ADD COLUMN eliminacion_programada  timestamptz,
  ADD COLUMN eliminada_en            timestamptz;

-- Historial de eliminaciones (solo ids y conteos, nada personal).
ALTER TABLE correcciones DROP CONSTRAINT correcciones_accion_check;
ALTER TABLE correcciones ADD CONSTRAINT correcciones_accion_check
  CHECK (accion IN ('corregir', 'anular', 'eliminar', 'anonimizar'));
