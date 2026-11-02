# Bitácora de Cambios y Recomendaciones de Hardening

## 1. Resumen de Cambios Aplicados

### A. Restricción de Exposición de Red (`postgresql.conf`)
* **Configuración Inicial:** `listen_addresses = '*'` / `0.0.0.0` (Escuchando en todas las interfaces de red).
* **Configuración Aplicada:** `listen_addresses = 'localhost'` (Limitado a la interfaz local `127.0.0.1`).
* **Justificación:** Aislar el puerto `5432` del acceso público para reducir la superficie de ataque y prevenir escaneos remotos no autorizados.

### B. Control de Acceso Basado en Hosts (`pg_hba.conf`)
* **Configuración Inicial:** Reglas permisivas habilitadas para cualquier origen de red (`0.0.0.0/0`).
* **Configuración Aplicada:** Eliminación de subredes globales universales y restricción explícita a direcciones IP autorizadas, exigiendo el algoritmo `scram-sha-256`.
* **Justificación:** Garantizar que únicamente clientes provenientes de subredes explícitamente declaradas puedan intentar la autenticación contra la base de datos.

### C. Auditoría y Cifrado de Canal (TLS/SSL)
* **Estado Auditado:** `ssl = false` verificado en la vista `pg_stat_ssl` (conexión en texto claro).
* **Plan de Acción:** Generación e instalación de certificados digitales (`server.crt` y `server.key`) para activar `ssl = on` y forzar directivas `hostssl` en `pg_hba.conf`.
* **Justificación:** Mitigar la intercepción de credenciales y la lectura de datos sensibles en tránsito dentro de la red (*eavesdropping* / ataques *Man-in-the-Middle*).

---

## 2. Recomendaciones Finales de Remediación

1. **Firewall a Nivel de SO:** Mantener habilitado el Firewall de Windows bloqueando el tráfico entrante al puerto 5432 desde redes no fidedignas.
2. **Segregación de Roles (RBAC):** Prohibir el uso operativo de la cuenta superusuario `postgres` y aplicar el principio de mínimo privilegio en cuentas de aplicación.
3. **Auditoría Activa:** Mantener habilitada la recolección de logs (`logging_collector = on`) registrando inicios/cierres de sesión (`log_connections`, `log_disconnections`) y consultas lentas o anómalas.