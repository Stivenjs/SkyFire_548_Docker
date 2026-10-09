# SkyFire 5.4.8 Docker (100% Automatizado)

Entorno completo y contenerizado con **Docker Compose** para desplegar un servidor **World of Warcraft: Mists of Pandaria (5.4.8 Build 18414)** basado en [Project SkyFire](https://github.com/ProjectSkyfire/SkyFire_548).

---

## Características de la Automatización

- **Cero archivos SQL en el repositorio**: No necesitas guardar ni mantener archivos `.sql` pesados en Git.
- **Descarga e Importación Automática (`db-init`)**: Al ejecutar Docker con el perfil `init`, un servicio descarga automáticamente los esquemas oficiales (`auth` y `characters`) y el release más reciente de la base de datos `world` (SFDB) desde Codeberg, los descomprime y los importa a MySQL.
- **Arranque Instantáneo en el Día a Día**: `db-init` funciona bajo un perfil independiente, permitiendo que tu servidor habitual levante en apenas 2 segundos.
- **Soporte de Mapas Externos (`GAME_DATA_PATH`)**: Puedes conectar carpetas de mapas directamente desde cualquier unidad externa (como un disco `D:`) sin duplicar gigabytes en tu disco principal.
- **Configuración Dinámica**: Genera y parametriza `authserver.conf` y `worldserver.conf` conectándolos automáticamente con las credenciales de tu `.env`.
- **Configuración de Reino Automática**: Ajusta la tabla `realmlist` con el nombre, IP y puerto configurados sin comandos manuales.

---

## Estructura de Servicios

| Servicio | Contenedor | Puerto | Perfil | Descripción |
|---|---|---|---|---|
| `mysql` | `skyfire-mysql` | `3306` | - | Servidor MySQL 8.4 con healthcheck activo |
| `db-init` | `skyfire-db-init` | - | `init` | Descarga y poblamiento automático de BD (bajo demanda) |
| `authserver` | `skyfire-authserver` | `3724` | - | Servidor de autenticación y lista de reinos |
| `worldserver` | `skyfire-worldserver` | `8085` | - | Servidor del mundo con soporte de consola interactiva |

---

## Guía de Configuración y Uso

### 1. Variables de Entorno (.env)

Copia o edita el archivo [.env](file:///c:/Users/xooty/Desktop/Code/SkyFire_548_Docker/.env):

```bash
cp .env.example .env
```

Parámetros clave en [.env](file:///c:/Users/usr/Desktop/Code/SkyFire_548_Docker/.env):
- `REALM_ADDRESS`: IP de conexión. Usa `127.0.0.1` para jugar en tu PC, o tu IP local/pública para amigos o VPS.
- `GAME_DATA_PATH`: *(Opcional)* Ruta hacia los mapas de tu cliente si los tienes en otro disco o carpeta.

---

### 2. Conectar los Datos del Juego (DBC, Maps, VMaps, MMaps)

Tienes dos métodos para proveer los mapas a `worldserver`:

#### Método A: Enlazar tu carpeta existente (Recomendado - No duplica disco)
Si ya tienes un repack o los mapas extraídos en otra ruta (por ejemplo en el disco `D:`), descomenta y define la variable `GAME_DATA_PATH` en tu archivo [.env](file:///c:/Users/usr/Desktop/Code/SkyFire_548_Docker/.env):

```ini
GAME_DATA_PATH=D:/MoP/MOP-5.4.8.18414-enUS-Repack/data
```
*(Docker montará esa carpeta directamente en modo solo lectura `ro` sin copiar nada)*.

#### Método B: Copiar manualmente en el proyecto
Coloca las carpetas extraídas dentro de la estructura local:

```
data/
└── server/
    └── game-data/
        ├── dbc/
        ├── maps/
        ├── mmaps/
        └── vmaps/
```

---

### 3. Puesta en Marcha

#### Paso A: Primera Ejecución (Inicializar Base de Datos)
La **primera vez** que levantes el servidor (o si borraste los volúmenes), ejecuta el perfil `init` para que descargue e importe la base de datos automáticamente:

```bash
docker compose --profile init up -d
```

Puedes seguir el progreso de descarga e importación de la base de datos en tiempo real:

```bash
docker compose logs -f db-init
```

---

#### Paso B: Uso Diario (Arranque Instantáneo)
Una vez que la base de datos ya está inicializada, para jugar día a día solo necesitas ejecutar:

```bash
docker compose up -d
```
*(Levanta MySQL, AuthServer y WorldServer en 1 a 2 segundos)*.

---

## Gestión y Comandos Útiles

### Reiniciar Servidores (Sin tocar la base de datos)
Si cambiaste configuraciones y quieres reiniciar los procesos del juego sin apagar MySQL:

```bash
docker compose restart authserver worldserver
```

### Consola Interactiva (Comandos GM y Crear Cuentas)

`worldserver` se ejecuta con terminal interactiva asignada. Para conectarte:

```bash
docker attach skyfire-worldserver
```

Una vez dentro de la consola del servidor (`SF>`), ejecuta:

```text
account create miusuario mipassword
account set gmlevel miusuario 3 -1
```

> **IMPORTANTE:** Para salir de la consola sin detener el servidor, presiona **`Ctrl + P`** seguido de **`Ctrl + Q`**.

### Detener los Servicios

```bash
docker compose down
```

---

## Volúmenes y Persistencia

- `skyfire-mysql-data`: Persiste todos los datos y tablas de MySQL.
- `skyfire-db-cache`: Caché interna para evitar volver a descargar el archivo de base de datos en caso de reconstrucción.
- `config/`: Donde residen tus archivos `authserver.conf` y `worldserver.conf` si deseas personalizarlos manualmente.
- `data/server/logs/`: Contiene los logs del servidor para fácil consulta.
