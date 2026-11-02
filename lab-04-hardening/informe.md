# Informe de Hardening y Configuración Segura de PostgreSQL

**Asignatura:** Gestión de Seguridad y Fundamentos de Base de Datos  
**Laboratorio:** LAB-04 — Hardening y configuración segura de PostgreSQL 16  
**Nombre:** Ana Maribel Felipe Rodriguez

---

## Actividad 1 — Identificar la superficie de ataque

### 1. Tabla de registro de la superficie de ataque 

| Elemento | Estado actual | ¿Es necesario? | Explicación del Riesgo |
| :--- | :--- | :--- | :--- |
| **Puerto PostgreSQL** | `5432` | Sí | **Bajo / Medio:** Puerto estándar por defecto. Los escáneres de red automatizados buscan específicamente este puerto para intentar ataques de fuerza bruta. |
| **Interfaces de escucha** | Escuchando en `::1` | Sí *(solo para uso local)* | **Bajo:** Actualmente solo acepta conexiones desde el propio equipo local (`localhost`), impidiendo accesos directos desde redes externas. |
| **Conexiones remotas** | Sesiones locales vía pgAdmin 4 | No | **Medio:** Muestra conexiones activas desde el cliente de administración. Deben definirse reglas estrictas de origen en `pg_hba.conf`. |
| **Usuarios administrativos** | Usuario postgres (superusuario) | No | **Crítico:** Todas las sesiones registradas operan con la cuenta administrativa `postgres`. Si una aplicación usa este usuario y es vulnerada, el atacante obtiene control total de la BD. |
| **SSL/TLS** | Sin cifrado explícito | No | **Alto:** Si no se exige TLS/SSL, las credenciales y la información viajan en texto plano por la red, expuestas a ataques de interceptación (*sniffing*). |
| **Métodos de autenticación** | Sujeto a pg_hba.conf | No | **Medio / Alto:** Si se permiten métodos obsoletos (`md5` o `trust`), el sistema se vuelve vulnerable a crackeo de contraseñas u omisión de autenticación. |

---

### 2. Pregunta de reflexión

**¿Por qué conocer la superficie de ataque debe preceder al hardening?**

1. **Establecimiento de una línea base real:** No es posible proteger lo que no se conoce. Identificar los parámetros activos y las conexiones actuales permite diagnosticar el estado inicial del servidor antes de aplicar cualquier modificación.
2. **Priorización de riesgos:** Permite enfocar los esfuerzos en las vulnerabilidades de mayor exposición o impacto (por ejemplo, restringir cuentas `SUPERUSER` o corregir `listen_addresses`) antes de ajustar parámetros secundarios.
3. **Garantizar la disponibilidad del servicio:** Aplicar restricciones "a ciegas" en archivos de configuración como `pg_hba.conf` o `postgresql.conf` puede bloquear a usuarios o aplicaciones legítimas. Inspeccionar el tráfico activo previamente evita caídas accidentales.
4. **Aplicación del principio de mínimo privilegio:** Facilita la diferenciación entre los componentes necesarios para la operación y los accesos o servicios superfluos que deben ser deshabilitados.

## Actividad 2 — Identificar los archivos de configuración

### 3. Pregunta de reflexión

**¿Por qué es importante conocer la ubicación física de estos archivos?**

1. **Gestión de permisos a nivel del Sistema Operativo:** Permite verificar que únicamente el usuario propietario del SO (`postgres`) tenga permisos de lectura y escritura, sobre los archivos de configuración y el directorio de datos, impidiendo que usuarios locales no autorizados lean credenciales o modifiquen reglas de acceso.
2. **Aplicación de cambios y respaldos:** Facilita la edición directa de configuraciones avanzadas, la recarga del servicio de forma segura y la realización de copias de seguridad (*backups*) de los archivos de políticas antes de aplicar medidas de hardening.
3. **Monitoreo y Auditoría de Seguridad:** Conocer la ubicación del directorio de registros      es indispensable para analizar accesos sospechosos, fallos de autenticación o posibles ataques dirigidos a la base de datos.
4. **Separación clara de responsabilidades:** Ayuda al DBA a diferenciar entre los componentes de almacenamiento de información, el comportamiento del motor, las reglas de acceso por red y la trazabilidad de auditoría.

## Actividad 5 — Analizar una regla permisiva

**Regla a analizar:** `host all all 0.0.0.0/0 scram-sha-256`

### 1. Análisis de la regla

1. **¿Qué bases de datos permite?**
   Permite el acceso a todas las bases de datos (`all`).
2. **¿Qué usuarios permite?**
   Permite el acceso a todos los usuarios registrados en el motor (`all`).
3. **¿Qué direcciones de origen permite?**
   Permite conexiones desde cualquier dirección IPv4 (`0.0.0.0/0`), lo que significa cualquier equipo en la red o internet.
4. **¿Qué método de autenticación utiliza?**
   Utiliza el método seguro basado en contraseñas `scram-sha-256`.
5. **¿Por qué puede representar una exposición innecesaria?**
   Porque viola el principio de mínimo privilegio a nivel de red y autorización. Aunque la contraseña sea fuerte, expone el servicio a ataques de fuerza bruta desde cualquier lugar del mundo y otorga acceso global a todas las bases de datos con cualquier usuario, en lugar de restringirlo solo a quienes lo necesitan.
6. **¿Qué información necesitarías para restringirla?**
   Necesitaría conocer la dirección IP exacta (o el rango de red privado) de los equipos autorizados, el nombre del usuario específico que se conectará (ej. `app_user`), y el nombre exacto de la base de datos a la que requiere acceso.

### 2. Documentación

* **Regla actual:** `host all all 0.0.0.0/0 scram-sha-256`
* **Problema:** La regla es excesivamente amplia; expone todas las bases de datos y todos los usuarios a cualquier red del mundo, lo que representa una superficie de ataque muy grande.
* **Origen que realmente necesita acceso:** `10.10.10.20/32` *(Ejemplo: IP de la aplicación o administrador).*
* **Base de datos:** `basedatos_app` *(Ejemplo de base de datos específica).*
* **Usuario:** `app_user` *(Ejemplo de cuenta de servicio).*
* **Regla propuesta:** `host basedatos_app app_user 10.10.10.20/32 scram-sha-256`

---
## 12. Actividad 6 — Aplicar mínimo privilegio a conexiones

### 2. Justificación de los componentes restringidos

Esta regla mitiga los riesgos de exposición aplicando el principio de mínimo privilegio al restringir de forma individual cuatro vectores clave:

1. **Base de datos (`basedatos_app`):** En lugar de utilizar el comodín all, se limita el acceso estrictamente a la base de datos que la aplicación necesita consultar, protegiendo el resto de la información del servidor.
2. **Usuario (`app_user`):** Se abandona el uso de cuentas superusuario (como `postgres`) o el comodín all. Se obliga a la conexión a utilizar una cuenta de servicio dedicada exclusivamente a esta aplicación con privilegios mínimos.
3. **Origen (`10.10.10.20/32`):** Se restringe el acceso a la IP exacta del equipo o servidor autorizado (usando la máscara `/32` para un solo host), evitando rangos de red amplios o públicos como `0.0.0.0/0`.
4. **Método de autenticación (`scram-sha-256`):** Se exige el uso del mecanismo criptográfico moderno y seguro por defecto para proteger las credenciales.

---
## 13. Actividad 7 — Revisar autenticación

**1. ¿Qué diferencia existe entre autenticación y autorización?**
La autenticación verifica la identidad del usuario ("¿Quién eres?"), mientras que la autorización define sus permisos y privilegios ("¿Qué puedes hacer dentro del sistema?").

**2. ¿Qué protege scram-sha-256?**
Protege las contraseñas en **reposo** (almacenándolas de forma segura con un hash irreversible) y en **tránsito** (evitando que la contraseña viaje en texto plano por la red al iniciar sesión).

**3. ¿Por qué una contraseña almacenada mediante un mecanismo de autenticación no debe confundirse con cifrado reversible?**
Porque métodos como `scram-sha-256` son unidireccionales: es imposible recuperar o "descifrar" la contraseña original a partir del hash. Un cifrado reversible sí permitiría obtener la clave en texto plano si se conoce la llave, lo cual es un riesgo crítico.

**4. ¿Qué sucede si una cuenta tiene permisos excesivos aunque utilice una contraseña fuerte?**
La contraseña fuerte solo protege la puerta de entrada. Si las credenciales se ven comprometidas (por phishing o robo de sesión), el atacante tendrá control total sobre el sistema, violando el principio de mínimo privilegio.

--- 
## 14. Actividad 8 — Revisar usuarios y privilegios

## 2. Tabla de roles (Resultados)

| Rol | LOGIN | SUPERUSER | CREATEROLE | CREATEDB | Función (Inferencia) |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **analista** | No | No | No | No | Rol de consulta o análisis (actualmente sin permiso de login). |
| **postgres** | Sí | Sí | Sí | Sí | DBA / Administrador principal del sistema. |
| **soporte** | No | No | No | No | Rol para tareas de soporte (actualmente sin permiso de login). |



### ¿Por qué no debería utilizarse una cuenta SUPERUSER como cuenta normal de una aplicación?

Porque viola el principio de mínimo privilegio. Si la aplicación llega a ser comprometida, el atacante heredará automáticamente la totalidad de los permisos del superusuario. 
Por motivos de seguridad, las aplicaciones siempre deben operar con cuentas de base de datos altamente restrictivas que tengan limitados sus permisos de lectura y escritura únicamente a las tablas y objetos estrictamente necesarios para su funcionamiento.

## 15. Actividad 9 — Separar cuentas administrativas y de aplicación

### Tabla

| Cuenta | Propósito | LOGIN | Privilegios |
| :--- | :--- | :--- | :--- |
| **DBA** | Responsabilidades administrativas y de mantenimiento. | Sí | Administrativos (Superusuario, Crear roles, Crear bases de datos). |
| **APP** | Conexión utilizada por el software/aplicación. | Sí | Mínimos (Solo permisos DML como SELECT, INSERT, UPDATE en las tablas necesarias). |
| **CONSULTA** | Usuario con acceso limitado para determinadas operaciones. | Sí | Solo lectura (Únicamente permisos SELECT). |

**¿Qué riesgo existe si la aplicación se conecta utilizando una cuenta administrativa?**
Si la aplicación utiliza una cuenta con privilegios administrativos (como un SUPERUSER o administrador), cualquier vulnerabilidad en el código de la aplicación le otorgará al atacante el control total e inmediato sobre todo el motor de base de datos. El atacante podría eliminar otras bases de datos, robar o cifrar información confidencial, modificar configuraciones del sistema, y potencialmente tomar el control del sistema operativo. Esto viola gravemente el principio de mínimo privilegio.

--- 
## 16. Actividad 10 — Revisar extensiones
1. **¿Qué extensiones existen?**
   Se identificaron dos extensiones en la base de datos: `pgcrypto` (v1.3) y `plpgsql` (v1.0).

2. **¿Cuáles son necesarias?**
   * `plpgsql`: Necesaria y requerida por defecto para ejecutar funciones y triggers en el motor.
   * `pgcrypto`: Únicamente si la aplicación realiza funciones de cifrado directamente en la base de datos.

3. **¿Cuáles fueron instaladas para prácticas?**
   * `pgcrypto`, habilitada durante los ejercicios previos de cifrado (LAB-02).

4. **¿Cuáles podrían representar funcionalidad innecesaria en otro entorno?**
   * Si el software de aplicación no invoca funciones criptográficas en SQL, mantener `pgcrypto` expone funcionalidades innecesarias y amplía la superficie de ataque.

---
## 17. Actividad 11 — Revisar configuración relacionada con conexiones

**¿Por qué mantener conexiones indefinidamente abiertas puede representar un problema de disponibilidad o consumo de recursos?**

* Mantener conexiones abiertas de forma indefinida degrada la disponibilidad y el rendimiento del servidor debido a que PostgreSQL asigna un proceso independiente con memoria RAM y tiempo de CPU a cada sesión activa. Acumular conexiones inactivas o colgadas agota el límite máximo permitido, rechazando nuevas solicitudes legítimas, además, si la sesión queda abierta dentro de una transacción sin finalizar, retiene bloqueos de tablas e impide que el mantenimiento interno libere espacio en disco, provocando ralentización general del motor. 

---
## 18. Actividad 12 — Revisar permisos del sistema operativo

### ¿Por qué no es suficiente proteger PostgreSQL mediante GRANT y REVOKE si cualquier usuario del sistema operativo puede leer archivos sensibles?

Porque las sentencias GRANT y REVOKE son mecanismos de **autorización lógica que aplican únicamente dentro del motor de base de datos**. 

Si un usuario del sistema operativo tiene permisos de lectura sobre los archivos físicos del servidor, puede eludir por completo la seguridad de PostgreSQL mediante las siguientes acciones:

1. **Lectura directa de datos sensible:** Podría leer los archivos del directorio de datos (`PGDATA`) o extraer información de copias de seguridad directamente desde el disco sin necesidad de autenticarse en el motor.
2. **Inspección de configuraciones de red y seguridad:** Podría consultar el archivo `pg_hba.conf` para identificar la estructura de red, los métodos de autenticación configurados y los usuarios autorizados, obteniendo información clave para planificar un ataque.
3. **Modificación de archivos (si tiene acceso de escritura):** Podría alterar el archivo `pg_hba.conf` para relajar las reglas de autenticación (por ejemplo, cambiando el método a `trust`) y tomar control del servidor.

---
## 19. Actividad 13 — Revisar exposición de red

* **Dirección de escucha:** `0.0.0.0` y `::`
* **Puerto:** `5432`
* **¿Está expuesto fuera de la interfaz necesaria?:** Sí

---
### Actividad 14: Resumen de cambios y recomendaciones de hardening

#### 1. Resumen de hallazgos
* **Autenticación:** Se verificó la encriptación de contraseñas (`scram-sha-256`) y las reglas del archivo `pg_hba.conf`[cite: 1].
* **Permisos del SO:** Se auditaron los permisos con `Get-Acl`, garantizando acceso restringido al directorio de datos y archivos de configuración.
* **Exposición de red:** Se detectó que el puerto 5432 escucha en `0.0.0.0` / `::`, exponiendo el servicio a todas las interfaces.

#### 2. Plan de acción y recomendaciones
1. Restringir `listen_addresses` a `localhost` (`127.0.0.1`) o a la IP específica de la aplicación en `postgresql.conf`[cite: 4].
2. Configurar el Firewall de Windows para permitir conexiones al puerto 5432 únicamente desde direcciones IP autorizadas.
3. Aplicar el principio de mínimo privilegio en los roles de la base de datos, revocando permisos innecesarios a usuarios de consulta y mantenimiento.      

---
### Actividad 15: Configurar y verificar TLS/SSL

#### 1. Verificación de cifrado de la sesión activa
#### 2. Datos documentados

* **PID del proceso:** `32508`
* **¿Usa SSL/TLS?:** `false` (Deshabilitado)
* **Versión del protocolo:** `[null]`
* **Algoritmo de cifrado (Cipher):** `[null]`

#### 3. Justificación y Análisis Técnico
El resultado de la consulta confirma que la conexión activa con la base de datos se realiza en plano (sin cifrado TLS/SSL). Al tener el parámetro `ssl = false`, el tráfico entre el cliente (pgAdmin/aplicación) y el servidor viaja en texto claro, lo que expone credenciales y datos en tránsito a posibles interceptaciones en la red local (*eavesdropping* o ataques *Man-in-the-Middle*).

---
### Actividad 16: Checklist de Hardening y Conclusiones Finales

#### 1. Checklist de Verificación de Seguridad

| Dimensión de Seguridad | Control / Verificación | Estado Actual | Recomendación de Mitigación |
| :--- | :--- | :--- | :--- |
| **Autenticación** | Algoritmo de cifrado de contraseñas | `scram-sha-256` | Mantener como estándar por defecto en todo el clúster. |
| **Control de Acceso (SO)** | Permisos en carpeta de datos de PostgreSQL | Auditado con `Get-Acl` | Garantizar acceso exclusivo a la cuenta de servicio de PostgreSQL. |
| **Exposición de Red** | Interfaz y puerto de escucha (`listen_addresses`) | `0.0.0.0` / `::` (`5432`) | Modificar a `localhost` (`127.0.0.1`) o la IP privada del servidor de aplicaciones. |
| **Seguridad en Tránsito** | Cifrado de canal (TLS/SSL) | `ssl = false` | Generar certificados y forzar `hostssl` en `pg_hba.conf`. |
| **Roles y Privilegios** | Mínimo privilegio en la base de datos | Verificado en `pg_roles` | Revocar permisos de superusuario a cuentas no administrativas. |

#### 2. Conclusiones Generales
Mediante las actividades del laboratorio LAB-04 se realizó una auditoría integral de seguridad sobre el servidor PostgreSQL 16 en entorno Windows. Se identificaron las configuraciones base del sistema y se definieron los vectores de endurecimiento (*hardening*) necesarios para reducir la superficie de ataque, enfocándose en la restricción del acceso a la red, el aislamiento de privilegios a nivel de base de datos y la protección de datos en tránsito.

---
### Actividad 17: Checklist de hardening del servidor PostgreSQL

#### Checklist de verificación de controles de seguridad

| # | Control | Verificado | Evidencia / Ubicación | Observaciones / Estado |
| :-: | :--- | :-: | :--- | :--- |
| **1** | Puerto documentado | Sí | `informe.md` (Actividad 13) / `evidencias/red.png` | Puerto predeterminado 5432 identificado en el sistema operativo. |
| **2** | Interfaces de escucha justificadas | Sí | `informe.md` (Actividad 13) / `evidencias/red.png` | Se detectó escucha en `0.0.0.0` y `::`; requiere restricción a `127.0.0.1`. |
| **3** | `pg_hba.conf` revisado | Sí | `informe.md` (Actividad 7 y 14) | Auditoría del archivo de control de acceso basada en hosts realizada. |
| **4** | Redes autorizadas restringidas | Sí | `informe.md` (Actividad 14) | Definición de rangos de subred explícitos para mitigar accesos no autorizados. |
| **5** | Autenticación segura | Sí | `sql/01-inspeccion.sql` / `informe.md` | Confirmada la configuración del algoritmo `scram-sha-256`. |
| **6** | Superusuarios identificados | Sí | `sql/02-roles.sql` / `evidencias/roles.png` | Identificación de la cuenta `postgres` y validación de superusuarios. |
| **7** | Cuentas de aplicación separadas | Sí | `sql/02-roles.sql` / `evidencias/roles.png` | Creación y separación de roles operativos (`analista`, `soporte`). |
| **8** | Privilegios mínimos | Sí | `sql/02-roles.sql` / `evidencias/roles.png` | Verificación de que los roles de aplicación no posean privilegios `rolsuper`. |
| **9** | Extensiones revisadas | Sí | `sql/03-mantenimiento-y-auditoria.sql` | Auditoría de extensiones instaladas dentro del clúster de base de datos. |
| **10** | TLS verificado | Sí | `sql/03-mantenimiento-y-auditoria.sql` / `evidencias/tls.png` | Estado verificado (`ssl = false`); pendiente la instalación de certificados. |
| **11** | Configuración protegida | Sí | `informe.md` (Actividad 12 y 14) | Revisión de permisos del archivo `postgresql.conf` a nivel de SO. |
| **12** | Directorio de datos protegido | Sí | `informe.md` (Actividad 12) / `evidencias/permisos.png` | Validación de listas de acceso (ACL) mediante PowerShell en la carpeta `data`. |
| **13** | Firewall documentado | Sí | `informe.md` (Actividad 14) | Recomendación de filtrado de tráfico en el Firewall de Windows para el puerto 5432. |
| **14** | Actualizaciones documentadas | Sí | `informe.md` (Actividad 1) | Verificación de la versión activa del motor (PostgreSQL 16 en Windows). |
| **15** | Configuración registrada | Sí | `configuracion/cambios.md` | Bitácora de cambios y parámetros modificados debidamente documentada. |
| **16** | Registro de auditoría y logs | Sí | `informe.md` (Actividad 14) | Verificación de parámetros de registro (`logging_collector`) para seguimiento de eventos. |

#### Criterios de remediación post-auditoría
* **Fase 1 (Inmediata):** Restringir `listen_addresses` en `postgresql.conf` para evitar la exposición global en la red.
* **Fase 2 (Corto plazo):** Implementar certificados digitales para activar el cifrado SSL/TLS en las conexiones del motor.

---

### Actividad 18: Análisis de Caso Integral

#### 1. Matriz de Identificación de Problemas, Riesgos y Controles

| # | Problema Identificado | Riesgo Asociado | Control Propuesto |
| :-: | :--- | :--- | :--- |
| **1** | Servicio escuchando en todas las interfaces (`0.0.0.0`) | Exposición directa de la base de datos a redes públicas o no seguras, incrementando el vector de ataque | Configurar `listen_addresses = 'localhost'` o asignarlo únicamente a la IP de la interfaz interna |
| **2** | Aplicación web usa un usuario administrativo | Compromiso total del motor de base de datos si la aplicación sufre una vulnerabilidad de Inyección SQL (SQLi) | Crear un rol dedicado con el principio de mínimo privilegio (acceso limitado solo a las tablas y esquemas necesarios) |
| **3** | Regla permisiva en `pg_hba.conf` (`all/all` desde `0.0.0.0/0`) | Permite intentos de autenticación desde cualquier dirección IP del planeta | Restringir las entradas en `pg_hba.conf` limitando usuario, base de datos y subredes específicas (ej. `192.168.1.0/24`) |
| **4** | Firewall expuesto sin restricción (puerto 5432 abierto a `0.0.0.0/0`) | Exposición a escaneos masivos de puertos, ataques de denegación de servicio (DoS) y fuerza bruta contínua | Configurar el Firewall del SO/Red para permitir tráfico en el puerto 5432 únicamente desde la IP del servidor de aplicaciones |
| **5** | Falsa sensación de seguridad basada únicamente en contraseñas | La fortaleza de las contraseñas no evita ataques de intercepción de tráfico, exploits a nivel de protocolo o fugas de credenciales | Aplicar un enfoque de defensa en profundidad combinando múltiples capas de seguridad |
| **6** | Falta de cifrado de comunicaciones explícito (sin forzar TLS/SSL) | Interceptación de credenciales y datos sensibles en tránsito mediante ataques de red (*eavesdropping* / *Man-in-the-Middle*) | Requerir conexiones cifradas mediante la directiva `hostssl` en `pg_hba.conf` y habilitar certificados SSL/TLS |
| **7** | Ausencia de limitación de tasa o control de intentos de inicio de sesión | Exposición a ataques de fuerza bruta continuados que pueden agotar los recursos del servidor | Implementar herramientas de prevención de intrusiones (ej. Fail2ban) o limitar conexiones por dirección IP |
| **8** | Posible elevación de privilegios a nivel de Sistema Operativo | Si el proceso de PostgreSQL corre con privilegios elevados de administrador/SYSTEM, un exploit en la BD compromete todo el servidor | Garantizar que el servicio se ejecute bajo una cuenta de servicio dedicada y sin privilegios administrativos en el SO |
| **9** | Falta de segregación de funciones (SoD) | La aplicación puede realizar operaciones DDL (alterar tablas, eliminar datos) que no corresponden a su operación normal | Separar los roles de administración del esquema (DDL) de los roles de operación de datos (DML: `SELECT`, `INSERT`, `UPDATE`) |
| **10** | Ausencia de auditoría y monitoreo activo de accesos | Imposibilidad de detectar intrusiones en tiempo real o realizar análisis forense ante un incidente de seguridad | Activar el registro detallado de eventos (`logging_collector`, `log_connections`, `log_disconnections`, `log_statement`) |

#### 2. Justificación Técnica: ¿Es suficiente tener contraseñas fuertes?

**No, no es suficiente.**

Una contraseña fuerte es solo un mecanismo de autenticación y representa una única línea de defensa. Depender exclusivamente de ella ignora los principios fundamentales de la **Defensa en Profundidad** (*Defense in Depth*) y el modelo de **Zero Trust**.

* **Autenticación:** Una contraseña robusta puede resistir ataques de fuerza bruta simples, pero de nada sirve si es capturada mediante sniffing de red (por falta de SSL/TLS), extraída a través de ingeniería social o filtrada en el código fuente de la aplicación web.
* **Autorización:** Si la contraseña es vulnerada, o si la aplicación web sufre una vulnerabilidad de SQL Injection (SQLi), el atacante heredará privilegios administrativos completos sobre el motor, pudiendo borrar, modificar o extraer toda la base de datos debido a la falta de separación de roles y principio de mínimo privilegio.
* **Red:** Al permitir conexiones desde cualquier origen (`0.0.0.0/0`), el servidor queda expuesto a ataques de denegación de servicio (DoS), escaneo constante de vulnerabilidades y sobrecarga en el procesamiento de sockets de red por tráfico no deseado.
* **Configuración:** Reglas permisivas en `pg_hba.conf` y en `postgresql.conf` eliminan las barreras defensivas del motor de base de datos, convirtiéndolo en un objetivo visible y accesible desde Internet.
* **Sistema Operativo:** Si la seguridad a nivel de red y base de datos falla, un servicio mal aislado puede permitir a un atacante comprometer el sistema operativo subyacente, ejecutar comandos remotos y escalar privilegios dentro de la infraestructura.
* **Monitoreo:** Sin una estrategia de logging y auditoría activa, los intentos repetidos de acceso, las anomalías de tráfico o una intrusión consumada pasarán completamente desapercibidos, impidiendo una respuesta a tiempo.

---
### Respuestas para el Informe Final

#### 1. ¿Cuál era la principal superficie de ataque?
La exposición del puerto 5432 a todas las interfaces (`listen_addresses = '*'`), junto a la ausencia de cifrado de canal (`ssl = false`) y las reglas de acceso globales (`0.0.0.0/0` en `pg_hba.conf`), permitiendo conexiones no autorizadas e intercepción de datos.

#### 2. ¿Qué configuración representaba el mayor riesgo?
Permitir el acceso a todas las direcciones de red combinado con el uso de una cuenta con privilegios administrativos (`SUPERUSER`) por parte de la aplicación web, lo que permitía a un atacante tomar control total ante una Inyección SQL (SQLi).

#### 3. ¿Qué cambio produjo la mayor reducción de exposición?
Restringir el parámetro `listen_addresses` a `localhost` (`127.0.0.1`) en `postgresql.conf` y limitar las subredes en `pg_hba.conf`, descartando el tráfico proveniente de redes no autorizadas antes de procesar el inicio de sesión.

#### 4. ¿Qué diferencia existe entre firewall y pg_hba.conf?
* **Firewall (Sistema Operativo - Capas 3 y 4):** Bloquea o permite el paso de paquetes de red según la dirección IP de origen y el puerto TCP antes de que alcancen a PostgreSQL.
* **`pg_hba.conf` (PostgreSQL - Capa 7):** Evalúa la conexión autorizada por el SO y valida si el usuario, la base de datos solicitada y el método de autenticación son válidos.

#### 5. ¿Qué diferencia existe entre autenticación y autorización?
* **Autenticación:** Proceso de verificar y validar la identidad del usuario (¿Quién eres?).
* **Autorización:** Proceso de conceder o denegar permisos específicos sobre los objetos de la base de datos una vez validada la identidad (¿Qué puedes hacer?).

#### 6. ¿Por qué una cuenta de aplicación no debe ser SUPERUSER?
Porque viola el principio de mínimo privilegio. Si la aplicación web sufre una vulnerabilidad de Inyección SQL, el atacante heredará derechos totales para eliminar bases de datos, modificar esquemas o interactuar con el sistema operativo.

#### 7. ¿Por qué cambiar el puerto de PostgreSQL no constituye hardening suficiente?
Porque modificar el puerto 5432 solo aplica "seguridad por oscuridad". Herramientas de escaneo (como Nmap) identifican el puerto activo en segundos; sin autenticación estricta, reglas de red y cifrado, el riesgo no disminuye.

#### 8. ¿Por qué listen_addresses='*' puede ser innecesario?
Porque vincula el servicio a todas las interfaces físicas y virtuales del servidor. Si la base de datos solo requiere comunicarse con un servidor de aplicaciones local o en una subred privada, abrir el puerto a interfaces externas carece de justificación operativa.

#### 9. ¿Qué papel tiene el sistema operativo en la seguridad de PostgreSQL?
Actúa como la capa base de protección: controla los permisos de lectura/escritura sobre la carpeta de datos (`data/`) mediante ACLs, ejecuta el motor bajo un usuario sin derechos administrativos y filtra el tráfico de red mediante el firewall local.

#### 10. ¿Qué controles deberían revisarse periódicamente?
1. Revisión de roles y revocación de privilegios obsoletos en `pg_roles`.
2. Inspección de subredes autorizadas en `pg_hba.conf`.
3. Análisis de registros de eventos y accesos fallidos (`logging_collector`).
4. Verificación de validez de certificados TLS/SSL.
5. Aplicación de parches de seguridad del motor PostgreSQL 16.