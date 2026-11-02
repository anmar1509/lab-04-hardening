-- 7. Actividad 1 — Identificar la superficie de ataque
-- Identificar los principales puntos de exposición del servidor PostgreSQL.
-- Ejecuta:
SELECT version();

-- Después:
SHOW port;
SHOW listen_addresses;
SHOW ssl;
SHOW password_encryption;

-- Obtén también información sobre las conexiones:
SELECT
pid,
usename,
datname,
client_addr,
client_port,
application_name
FROM pg_stat_activity;

-- 8. Actividad 2 — Identificar los archivos de configuración
-- Consulta:
SHOW config_file;
SHOW hba_file;
SHOW ident_file;


SHOW data_directory;
SHOW log_directory;
SHOW log_connections;
SHOW log_disconnections;

-- 9. Actividad 3 — Revisar listen_addresses
SHOW listen_addresses;

/*
Configuración encontrada: * (Escucha en todas las interfaces).

Interfaces necesarias: Únicamente localhost (para conexiones desde el propio servidor) y 
la IP privada específica de la red de administración o de la aplicación (por ejemplo, 10.10.10.20).

Interfaces innecesarias: Todas las demás interfaces de red públicas o 
segmentos no confiables que quedan expuestos al utilizar el comodín *.
*/

/*
Explica cuál arquitectura reduce mejor la exposición y por qué:
La segunda arquitectura reduce mejor la exposición porque aísla el servidor en una red privada detrás de un 
firewall que bloquea el tráfico de Internet. Esta defensa en profundidad evita que el motor de base de datos 
dependa únicamente de sus contraseñas, mitigando escaneos masivos y ataques de fuerza bruta desde el exterior, y
garantizando mediante la segmentación que solo los equipos internos autorizados puedan conectarse.
*/


-- 10. Actividad 4 — Revisar pg_hba.conf

SELECT type, database, user_name, address, auth_method FROM pg_hba_file_rules;

/*
Identifica:
* Reglas locales: (Ej. Encontradas reglas de tipo local para la base de datos all)

* Reglas para conexiones IPv4: (Ej. Reglas tipo host para direcciones como 127.0.0.1/32 o redes específicas)

* Reglas para conexiones IPv6: (Ej. Reglas tipo host para direcciones como ::1/128)

* Bases de datos afectadas: (Ej. Se aplican a all o replication)

* Usuarios afectados: (Ej. Aplican a all los usuarios o al usuario postgres)

* Redes permitidas: (Ej. Solo red local y la IP del servidor)

* Método de autenticación: (Ej. Se está utilizando scram-sha-256, md5 o trust)
*/

