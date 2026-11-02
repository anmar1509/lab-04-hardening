### Actividad 19: Propuesta de Baseline (Línea Base) de Seguridad para PostgreSQL 16

Un *baseline* o línea base de seguridad define los parámetros y requisitos mínimos obligatorios que debe cumplir la configuración del servidor PostgreSQL 16 antes de ser desplegado en un entorno de producción.

#### 1. Seguridad de Red

| Control | Especificación de la Línea Base |
| :--- | :--- |
| **Interfaces autorizadas** | Restringir el parámetro `listen_addresses` a `localhost` (`127.0.0.1`) o únicamente a la dirección IP de la interfaz de red privada asignada a la comunicación con la aplicación. Prohibido mantener `*` o `0.0.0.0`. |
| **Puerto de comunicación** | Cambiar el puerto por defecto (`5432`) a un puerto no estándar en entornos de alta exposición, o mantener el 5432 únicamente bajo aislamiento estricto por firewall. |
| **Firewall (SO / Red)** | Bloquear todo el tráfico entrante al puerto de PostgreSQL por defecto. Habilitar reglas explícitas que permitan únicamente el tráfico proveniente de las IPs fijas de los servidores de aplicaciones. |
| **Redes permitidas (`pg_hba.conf`)** | Declarar subredes específicas con máscara estricta (ejemplo: `10.0.1.0/24`) para cada tipo de conexión. Prohibido el uso de la regla universal `0.0.0.0/0`. |

---

#### 2. Autenticación

| Control | Especificación de la Línea Base |
| :--- | :--- |
| **Método de autenticación** | Configurar `password_encryption = scram-sha-256` de manera global en todo el clúster[cite: 1]. Exigir el método `scram-sha-256` en las entradas del archivo `pg_hba.conf`[cite: 1]. |
| **Políticas de credenciales** | Implementar contraseñas de alta complejidad (mínimo 16 caracteres, mezcla de mayúsculas, minúsculas, números y símbolos). Definir rotación periódica de claves de acceso. |
| **Cuentas administrativas** | Prohibir el uso directo de la cuenta `postgres` para operaciones del día a día o conexiones desde la aplicación. Renombrar o restringir el inicio de sesión remoto del superusuario. |

---

#### 3. Autorización y Control de Acceso

| Control | Especificación de la Línea Base |
| :--- | :--- |
| **Estructura de roles** | Aplicar el modelo RBAC (Control de Acceso Basado en Roles) mediante la creación de roles de grupo (`rol_lectura`, `rol_escritura`, `rol_admin`). |
| **Principio de mínimo privilegio** | Revocar los privilegios por defecto del esquema `public` (`REVOKE ALL ON SCHEMA public FROM PUBLIC;`). Asignar permisos estrictamente necesarios por tabla o función. |
| **Cuentas de aplicación** | Crear un usuario de base de datos exclusivo por cada microservicio o aplicación web. Dichas cuentas **nunca** deben poseer el atributo `SUPERUSER`, `CREATEDB` ni `CREATEROLE`. |

---

#### 4. Configuración del Motor (Hardening de Parámetros)

| Control | Especificación de la Línea Base |
| :--- | :--- |
| **Parámetros clave (`postgresql.conf`)** | • `shared_buffers`: Ajustado entre 25% y 40% de la RAM total.<br>• `logging_collector = on`: Habilitar la recolección activa de logs.<br>• `log_connections = on` y `log_disconnections = on`: Registrar accesos al sistema.<br>• `log_min_duration_statement = 250ms`: Auditar consultas lentas o anómalas. |
| **Control de extensiones** | Permitir únicamente extensiones firmadas y auditadas (ej. `pg_stat_statements`). Limitar la capacidad de instalar extensiones a la cuenta de superusuario. |
| **Límite de conexiones** | Configurar `max_connections` ajustado a la capacidad del servidor y utilizar un pooler de conexiones (como PgBouncer) para evitar ataques de agotamiento de recursos. |

---

#### 5. Seguridad en el Sistema Operativo

| Control | Especificación de la Línea Base |
| :--- | :--- |
| **Propietario de archivos** | El servicio de PostgreSQL debe ser ejecutado por un usuario de sistema dedicado y sin privilegios administrativos (ej. `postgres` en Linux o la cuenta de servicio local en Windows). |
| **Permisos de archivos** | Aplicar permisos `0700` (POSIX) o restringir las listas de control de acceso (ACLs) en Windows (`Get-Acl` / `icacls`) para garantizar acceso exclusivo a la cuenta del motor. |
| **Protección del directorio de datos** | La carpeta `data/` y los archivos de configuración (`postgresql.conf`, `pg_hba.conf`) deben estar aislados de otros usuarios del sistema operativo. |

---

#### 6. Cifrado y Protección de Datos

| Control | Especificación de la Línea Base |
| :--- | :--- |
| **Cifrado en tránsito (TLS)** | Habilitar `ssl = on` en `postgresql.conf`, configurar certificados X.509 (`ssl_cert_file` y `ssl_key_file`) y forzar directivas `hostssl` en `pg_hba.conf`[cite: 1]. |
| **Protección de credenciales** | Almacenar las credenciales de la aplicación en gestores de secretos en lugar de archivos de texto claro. |
| **Protección de información sensible** | Encriptar campos críticos (tarjetas, datos personales) a nivel de columna con la extensión `pgcrypto` o a nivel de volumen/disco.|

#### 7. Mantenimiento, Auditoría y Continuidad

| Control | Especificación de la Línea Base |
| :--- | :--- |
| **Actualizaciones del motor** | Aplicar parches de seguridad secundarios de PostgreSQL 16 (ej. 16.x) en un plazo máximo de 30 días tras su publicación oficial. |
| **Revisión periódica de seguridad** | Ejecutar auditorías trimestrales de roles (`pg_roles`), reglas de red (`pg_hba.conf`) y verificación de registros de eventos (logs). |
| **Documentación y control de cambios** | Registrar todo cambio en los archivos de configuración dentro de un repositorio de control de versiones o bitácora de cambios.|