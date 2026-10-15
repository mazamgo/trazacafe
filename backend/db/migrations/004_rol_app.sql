-- Rol con los permisos mínimos de la API: leer y escribir datos, sin poder
-- cambiar la estructura. Se asigna a la cuenta de servicio de Cloud Run y a
-- otras personas del equipo (GRANT trazacafe_app TO "correo@gmail.com").

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'trazacafe_app') THEN
    CREATE ROLE trazacafe_app NOLOGIN;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO trazacafe_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO trazacafe_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO trazacafe_app;

-- Las tablas de migraciones futuras quedan cubiertas también.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO trazacafe_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO trazacafe_app;
