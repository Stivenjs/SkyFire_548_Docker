# SkyFire 5.4.8 Docker (100% Automatizado)

Entorno completo y contenerizado con **Docker Compose** para desplegar un servidor **World of Warcraft: Mists of Pandaria (5.4.8 Build 18414)** basado en [Project SkyFire](https://github.com/ProjectSkyfire/SkyFire_548).

---

## Características de la Automatización

- **Cero archivos SQL en el repositorio**: No necesitas guardar ni mantener archivos `.sql` pesados en Git.
- **Descarga e Importación Automática (`db-init`)**: Al ejecutar Docker, un servicio de inicialización descarga automáticamente los esquemas oficiales (`auth` y `characters`) y el release más reciente de la base de datos `world` (SFDB) desde Codeberg, los descomprime y los importa a MySQL.
- **Configuración Dinámica**: Genera y parametriza `authserver.conf` y `worldserver.conf` conectándolos automáticamente con las credenciales de tu `.env`.
- **Configuración de Reino Automática**: Ajusta la tabla `realmlist` con el nombre, IP y puerto configurados sin comandos manuales.
- **Orden de Arranque Garantizado**: `authserver` y `worldserver` esperan automáticamente hasta que la base de datos esté 100% poblada y lista.

---

## Estructura de Servicios

| Servicio | Contenedor | Puerto | Descripción |
|---|---|---|---|
| `mysql` | `skyfire-mysql` | `3306` | Servidor MySQL 8.4 con healthcheck activo |
| `db-init` | `skyfire-db-init` | - | Descarga y poblamiento automático de BD (corre una sola vez) |
| `authserver` | `skyfire-authserver` | `3724` | Servidor de autenticación y lista de reinos |
| `worldserver` | `skyfire-worldserver` | `8085` | Servidor del mundo con soporte de consola interactiva |

---

## Guía de Inicio Rápido

### 1. Configurar Variables de Entorno

Copia o edita el archivo [.env](file:///c:/Users/xooty/Desktop/Code/SkyFire_548_Docker/.env):

```bash
cp .env.example .env
```

Ajusta la IP si vas a jugar en red local o en un VPS (`REALM_ADDRESS`). Para jugar en tu propia máquina déjalo en `127.0.0.1`.

### 2. Datos del Juego (DBC, Maps, VMaps, MMaps)

Coloca las carpetas extraídas de tu cliente WoW 5.4.8 en:

```
data/
└── server/
    └── game-data/
        ├── dbc/
        ├── maps/
        ├── mmaps/
        └── vmaps/
```

### 3. Iniciar el Servidor

Ejecuta el siguiente comando para compilar las imágenes e iniciar todos los servicios:

```bash
docker compose up -d
```

### 4. Monitorear la Inicialización

Puedes seguir el progreso de descarga e importación de la base de datos en tiempo real:

```bash
docker compose logs -f db-init
```

Una vez completado `db-init`, los contenedores `authserver` y `worldserver` arrancarán automáticamente:

```bash
docker compose logs -f worldserver
```

---

## Gestión y Comandos Útiles

### Consola Interactiva (Comandos de GM)

`worldserver` se ejecuta con terminal interactiva asignada. Para interactuar con la consola:

```bash
docker attach skyfire-worldserver
```

*(Para salir de la consola sin detener el servidor, presiona `Ctrl + P` seguido de `Ctrl + Q`)*.

### Crear una Cuenta y dar Rango GM

Para crear una cuenta en el servidor, conéctate a la consola interactiva de `worldserver`:

```bash
docker attach skyfire-worldserver
```

Una vez dentro de la consola del servidor (`SF>`), ejecuta:

```text
account create miusuario mipassword
account set gmlevel miusuario 3 -1
```

*(Presiona `Ctrl + P` y luego `Ctrl + Q` para salir de la consola sin cerrar el contenedor)*.

---

## Volúmenes y Persistencia

- `skyfire-mysql-data`: Persiste todos los datos y tablas de MySQL.
- `skyfire-db-cache`: Caché interna para evitar volver a descargar el archivo de base de datos en caso de reconstrucción.
- `config/`: Donde residen tus archivos `authserver.conf` y `worldserver.conf` si deseas personalizarlos manualmente.
- `data/server/logs/`: Contiene los logs del servidor para fácil consulta.
