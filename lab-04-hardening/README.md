# LAB-04 — Hardening y configuración segura de PostgreSQL

## Objetivo
Evaluar, auditar y aplicar directivas de hardening (endurecimiento de la configuración) sobre una instancia del motor de base de datos PostgreSQL 16 en entorno Windows. El propósito fundamental es reducir la superficie de ataque inicial del servidor, implementar el principio de mínimo privilegio en el control de acceso, asegurar las comunicaciones de red y proteger los archivos del sistema operativo y las credenciales de acceso.

---

## Entorno
* **Motor de Base de Datos:** PostgreSQL 16
* **Sistema Operativo:** Windows Server / Windows 10/11
* **Herramientas de Administración:** pgAdmin 4, psql (CLI), Windows PowerShell
* **Lógica de Directorios:**
  * Archivos de configuración: `C:\Program Files\PostgreSQL\16\data\` (`postgresql.conf`, `pg_hba.conf`)
  * Directorio de datos del clúster: `C:\Program Files\PostgreSQL\16\data`

---

## Superficie de ataque inicial
Durante la inspección de la instalación por defecto del motor, se identificaron los siguientes vectores de exposición:

1. **Escucha global en red:** El parámetro `listen_addresses` configurado en `0.0.0.0` (IPv4) y `::` (IPv6), permitiendo la recepción de tráfico en el puerto `5432` a través de todas las interfaces de red del equipo.
2. **Conexiones sin cifrar:** Parámetro `ssl = false`, transmitiendo credenciales y consultas en texto claro (*plain text*).
3. **Reglas de acceso permisivas:** Archivo `pg_hba.conf` con reglas implícitas que permiten conexiones desde cualquier subred (`0.0.0.0/0`).
4. **Roles de superusuario:** Uso generalizado de la cuenta de superusuario `postgres` para consultas y operaciones rutinarias del cliente/aplicación.

---

## Hallazgos
* **Autenticación:** El motor utiliza el algoritmo de cifrado de contraseñas por defecto `scram-sha-256`, garantizando la protección de los hashes almacenados.
* **Permisos del Sistema Operativo:** Las listas de control de acceso (ACLs) auditadas mediante `Get-Acl` mostraron la necesidad de restringir el acceso exclusivo al directorio de datos a la cuenta de servicio local del motor.
* **Sesiones y Cifrado:** Al auditar la vista `pg_stat_ssl`, se confirmó que la sesión activa opera sin cifrado (`ssl = false`, `version = null`, `cipher = null`)[cite: 1].

---

## Cambios realizados
1. **Restricción de interfaces de red:** Modificación de `listen_addresses = 'localhost'` en `postgresql.conf` para aislar el puerto `5432` a la interfaz local `127.0.0.1`.
2. **Creación de roles segregados:** Implementación del modelo RBAC mediante la creación de roles específicos (`analista`, `soporte`) sin atributo `SUPERUSER` y revocación de permisos explícitos sobre el esquema `public`.
3. **Restricción en `pg_hba.conf`:** Reemplazo de la subred `0.0.0.0/0` por rangos de IP específicos de la aplicación y exigencia del método `scram-sha-256`[cite: 1].
4. **Generación de script de auditoría:** Creación del archivo `sql/verificacion.sql` para automatizar la comprobación de la seguridad del clúster.

---

## Justificación de los cambios
* **Escucha restringida:** Previene la exposición directa del motor a escaneos remotos, ataques de denegación de servicio (DoS) y vectorización de exploits fuera del ámbito exclusivo de la aplicación.
* **Principio de Mínimo Privilegio:** Limita el impacto de vulnerabilidades como la Inyección SQL (SQLi). Al restringir los roles de aplicación, un atacante no puede alterar la estructura de la base de datos ni acceder al sistema operativo.
* **Autenticación robusta y cifrado:** Evita ataques de fuerza bruta simples y mitiga la intercepción de credenciales mediante *sniffing* o ataques *Man-in-the-Middle* (MitM) en el tráfico de la red local[cite: 1].

---

## Verificación
La validación final de la configuración segura del servidor se llevó a cabo mediante:

1. **Consola del Sistema Operativo (PowerShell):**
   ```powershell
   Get-NetTCPConnection -LocalPort 5432

---

#### 1. Checklist de Verificación de Seguridad (16 Controles)

| # | Control | Estado Verificado | Ubicación / Evidencia | Observaciones / Acción Requerida |
| :-: | :--- | :-: | :--- | :--- |
| **1** | Puerto por defecto documentado | Sí | `informe.md` (Actividad 13) | Puerto 5432 identificado y auditado en la pila de red del SO. |
| **2** | Interfaces de escucha justificadas | Sí | `evidencias/red.png` / `postgresql.conf` | Detectado en `0.0.0.0`; se restringe a `127.0.0.1` (`localhost`). |
| **3** | Reglas de `pg_hba.conf` revisadas | Sí | `informe.md` (Actividad 7 y 14) | Eliminación de accesos globales no restringidos. |
| **4** | Subredes autorizadas restringidas | Sí | `informe.md` (Actividad 14) | Definición estricta de direccionamiento IP para clientes autorizados. |
| **5** | Autenticación `scram-sha-256` requerida | Sí | `sql/01-inspeccion.sql`[cite: 1] | Algoritmo de hash verificado como estándar activo en el clúster[cite: 1]. |
| **6** | Superusuarios identificados y limitados | Sí | `sql/02-roles.sql` / `evidencias/roles.png` | Verificación de la cuenta `postgres` y eliminación de superusuarios innecesarios. |
| **7** | Cuentas de aplicación independientes | Sí | `sql/02-roles.sql` | Segregación de roles operativos (`analista`, `soporte`) fuera del canal admin. |
| **8** | Principio de mínimo privilegio aplicado | Sí | `sql/02-roles.sql` | Revocación de permisos universales sobre el esquema `public`. |
| **9** | Extensiones auditadas | Sí | `sql/03-mantenimiento-y-auditoria.sql` | Verificación de extensiones instaladas (`pg_extension`). |
| **10** | Cifrado en tránsito verificado (TLS/SSL) | Sí | `evidencias/tls.png` / `pg_stat_ssl`[cite: 1] | Confirmado estado actual (`ssl = false`)[cite: 1]; recomendada emisión de certificados. |
| **11** | Archivos de configuración protegidos | Sí | `informe.md` (Actividad 12) | Restricción de permisos de lectura a `postgresql.conf` y `pg_hba.conf`. |
| **12** | Directores de datos protegidos (SO) | Sí | `evidencias/permisos.png` | Validación de ACLs en Windows mediante `Get-Acl` sobre la carpeta `data`. |
| **13** | Filtrado en Firewall documentado | Sí | `informe.md` (Actividad 14) | Regla de bloqueo perimetral en Windows Firewall para la interfaz de red pública. |
| **14** | Versión oficial del motor registrada | Sí | `sql/01-inspeccion.sql` | Confirmación de la versión activa (PostgreSQL 16 en Windows). |
| **15** | Control y registro de cambios estructurado | Sí | `configuracion/cambios.md` | Bitácora de modificaciones y parámetros del servidor debidamente documentada. |
| **16** | Auditoría y registro de eventos (Logs) | Sí | `informe.md` (Actividad 14) | Verificación de parámetros de captura de eventos (`logging_collector`). |

---

## Conclusiones
La realización del laboratorio LAB-04 permitió establecer una línea base (*baseline*) sólida para la administración segura de PostgreSQL 16 sobre el sistema operativo Windows. A través del análisis técnico y la reconfiguración de parámetros clave, se demostró que la seguridad en entornos de bases de datos debe abordar la gestión del servicio desde una perspectiva de Defensa en Profundidad, la fortaleza de las contraseñas resulta insuficiente si el tráfico viaja en plano (`ssl = false`), el servicio escucha en interfaces globales (`listen_addresses = '0.0.0.0'`) o la aplicación web opera con privilegios de superusuario. La mitigación efectiva de riesgos como la intercepción de credenciales, el acceso no autorizado y la ejecución de Inyecciones SQL requiere una combinación estricta de aislamiento de red, segregación de roles mediante el principio de mínimo privilegio, restricción de permisos a nivel del sistema operativo mediante ACLs y monitoreo continuo de eventos.