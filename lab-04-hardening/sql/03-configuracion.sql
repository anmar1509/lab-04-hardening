-- 16. Actividad 10 — Revisar extensiones
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- 17. Actividad 11 — Revisar configuración relacionada con conexiones
SHOW max_connections;
SHOW superuser_reserved_connections;
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;

-- 18. Actividad 12 — Revisar permisos del sistema operativo
SHOW data_directory;
SHOW config_file;
SHOW hba_file;


	
