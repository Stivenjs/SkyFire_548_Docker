# SkyFire 5.4.8 Docker 

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

`worldserver` requiere las carpetas de datos extraídos (`dbc`, `maps`, `vmaps`, `mmaps`). Tienes tres alternativas según tu caso:

#### Método A: Enlazar carpeta externa ya extraída (Recomendado si ya los tienes)
Si ya tienes los mapas extraídos en otra ruta o disco (por ejemplo `D:/MoP/Server_Data`), define la variable `GAME_DATA_PATH` en tu archivo [.env](file:///c:/Users/usr/Desktop/Code/SkyFire_548_Docker/.env):

```ini
GAME_DATA_PATH=D:/MoP/Server_Data
```
*(Docker montará esa carpeta directamente en `/opt/skyfire-server/data` en modo solo lectura `ro`, sin duplicar gigabytes en tu disco).*

---

#### Método B: Extraer automáticamente desde el cliente del juego (Si solo tienes el WoW)
Si únicamente tienes la carpeta del cliente de WoW 5.4.8 (con los archivos `.MPQ`), puedes usar el contenedor integrado para extraer automáticamente los mapas (`mapextractor`, `vmap4extractor`, `vmap4assembler`, `mmaps_generator`):

1. Configura la ruta a tu cliente de WoW en el archivo [.env](file:///c:/Users/usr/Desktop/Code/SkyFire_548_Docker/.env):
   ```ini
   CLIENT_PATH=D:/MoP/MOP-5.4.8.18414-enUS-Repack
   ```

2. Ejecuta el servicio extractor (mediante scripts o comando):
   - **En Windows**: doble clic en [`scripts/extract-data.bat`](file:///c:/Users/xooty/Desktop/Code/SkyFire_548_Docker/scripts/extract-data.bat) o ejecuta [`scripts/extract-data.ps1`](file:///c:/Users/xooty/Desktop/Code/SkyFire_548_Docker/scripts/extract-data.ps1)
   - **En Linux / WSL / macOS**: ejecuta `./scripts/extract-data.sh`
   - **Por comando directo (Universal)**:
     ```bash
     docker compose --profile tools run --rm --no-deps extractor
     ```

> [!NOTE]
> Los datos se guardarán automáticamente en `data/server/game-data/`. La generación de `mmaps` puede demorar varias horas debido al cálculo exhaustivo de rutas y mallas de navegación.

---

#### Método C: Copiar manualmente en el proyecto
Coloca las carpetas extraídas dentro de la estructura local del proyecto:

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

> [!IMPORTANT]
> Sigue los pasos **en orden**. El Paso A (build) es obligatorio antes de cualquier otro comando, ya que todos los servicios dependen de la imagen compilada.

#### Paso A: Compilar la Imagen Docker (Obligatorio la primera vez)
Esto compila SkyFire 548 desde código fuente y crea la imagen `skyfire548-server:latest`. Este proceso tarda varios minutos pero solo se ejecuta una vez:

```bash
docker compose build
```

> [!NOTE]
> Si en el futuro modificas el Dockerfile y quieres forzar una recompilación, ejecuta `docker compose build --no-cache`.

---

#### Paso B: Inicializar la Base de Datos (Primera vez o tras borrar volúmenes)
Con la imagen ya construida, ejecuta el perfil `init` para descargar e importar automáticamente las bases de datos (`auth`, `characters`, `world`/SFDB):

```bash
docker compose --profile init up db-init
```

Esto levantará MySQL, esperará a que esté listo, y ejecutará toda la inicialización de forma automática. Puedes seguir el progreso en tiempo real:

```bash
docker compose logs -f db-init
```

> [!TIP]
> Espera a que `db-init` termine completamente (verás `Proceso completado exitosamente`) antes de continuar al siguiente paso.

---

#### Paso C: Uso Diario (Arranque del Servidor)
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

### Creación de Cuentas (Método Rápido e Interactivo)

El proyecto incluye un script en Python ([`scripts/create_account.py`](file:///c:/Users/usr/Desktop/Code/SkyFire_548_Docker/scripts/create_account.py)) que calcula automáticamente el hash criptográfico SRP-6 nativo de MoP 5.4.8 y registra la cuenta en la base de datos de forma dinámica (lee las contraseñas de tu archivo [`.env`](file:///c:/Users/usr/Desktop/Code/SkyFire_548_Docker/.env) automáticamente 

#### Modo Interactivo (Pregunta Usuario, Contraseña y Nivel GM):
```bash
python scripts/create_account.py
```
> Te solicitará el nombre de usuario, la contraseña (con texto oculto) y el nivel de acceso (0 para jugador normal, 4 para GM Supremo / Administrador).

#### Modo Directo por Línea de Comandos:
```bash
python scripts/create_account.py <usuario> <contraseña> [nivel_gm]
```
*Ejemplo (Crear GM Supremo):*
```bash
python scripts/create_account.py mi_admin superclave 4
```

---

### Consola Interactiva de WorldServer (Alternativa Manual)

`worldserver` también soporta la terminal interactiva de SkyFire. Para conectarte:

```bash
docker attach skyfire-worldserver
```

Una vez dentro de la consola del servidor (`SF>`), ejecuta:

```text
account create miusuario mipassword
account set gmlevel miusuario 4 -1
```

> [!NOTE]
> Niveles de GM:
> - `0`: Jugador normal
> - `1`: Moderador
> - `2`: Game Master (GM)
> - `3`: Bug Hunter / Desarrollador
> - `4`: Administrador / GM Supremo (Acceso total a todos los comandos)
>
> El `-1` indica que el rango aplica para todos los reinos.

> [!CAUTION]
> Para salir de la consola sin detener el servidor, presiona **`Ctrl + P`** seguido de **`Ctrl + Q`**. Si presionas `Ctrl + C`, apagarás el servidor.

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
