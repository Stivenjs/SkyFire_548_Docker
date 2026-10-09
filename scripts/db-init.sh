#!/bin/bash
set -e

MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASS="${MYSQL_ROOT_PASSWORD}"
SKYFIRE_USER="${SKYFIRE_DB_USER:-skyfire}"
SKYFIRE_PASS="${SKYFIRE_DB_PASSWORD:-skyfire}"

REALM_NAME="${REALM_NAME:-SkyFire 5.4.8}"
REALM_ADDRESS="${REALM_ADDRESS:-127.0.0.1}"
REALM_PORT="${REALM_PORT:-8085}"
SKYFIRE_REF="${SKYFIRE_REF:-main}"

CACHE_DIR="/database_cache"
mkdir -p "$CACHE_DIR"

# Flags para compatibilidad total con MySQL 8.4 y caching_sha2_password
MYSQL_OPTS="--get-server-public-key"
MYSQL_CMD="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_OPTS"

echo "=========================================================="
echo "    [SkyFire DB-Init] Automatización de Base de Datos    "
echo "=========================================================="

# 1. Esperar a MySQL (Red y Autenticación)
echo "==> Verificando disponibilidad de red en $MYSQL_HOST:$MYSQL_PORT..."
until nc -z "$MYSQL_HOST" "$MYSQL_PORT"; do
    echo "    Esperando puerto MySQL..."
    sleep 2
done
echo "==> Puerto disponible. Autenticando con MySQL..."

TRIES=0
while true; do
    ERR_OUTPUT=$($MYSQL_CMD -e "SELECT 1;" 2>&1) && break
    TRIES=$((TRIES + 1))
    echo "    [Intento $TRIES] MySQL respondió con error:"
    echo "    $ERR_OUTPUT"
    if [ "$TRIES" -ge 30 ]; then
        echo "ERROR: No se pudo conectar a MySQL tras $TRIES intentos."
        exit 1
    fi
    sleep 3
done
echo "==> Conexión a MySQL confirmada exitosamente."

# 2. Asegurar creación de bases de datos y permisos de usuario
echo "==> Verificando existencia de bases de datos (auth, characters, world)..."
$MYSQL_CMD -e "
CREATE DATABASE IF NOT EXISTS \`auth\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`characters\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`world\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${SKYFIRE_USER}'@'%' IDENTIFIED BY '${SKYFIRE_PASS}';
ALTER USER '${SKYFIRE_USER}'@'%' IDENTIFIED BY '${SKYFIRE_PASS}';
GRANT ALL PRIVILEGES ON \`auth\`.* TO '${SKYFIRE_USER}'@'%';
GRANT ALL PRIVILEGES ON \`characters\`.* TO '${SKYFIRE_USER}'@'%';
GRANT ALL PRIVILEGES ON \`world\`.* TO '${SKYFIRE_USER}'@'%';
FLUSH PRIVILEGES;
"

# 3. Inicializar Auth Database
AUTH_TABLE_COUNT=$($MYSQL_CMD -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'auth';")
if [ "$AUTH_TABLE_COUNT" -eq 0 ]; then
    echo "--> [Auth] Base de datos vacía. Obteniendo auth_database.sql..."
    AUTH_SQL="$CACHE_DIR/auth_database.sql"
    if [ ! -f "$AUTH_SQL" ]; then
        if [ -f "/opt/skyfire-server/sql/base/auth_database.sql" ]; then
            cp "/opt/skyfire-server/sql/base/auth_database.sql" "$AUTH_SQL"
        else
            echo "    Descargando auth_database.sql desde GitHub ($SKYFIRE_REF)..."
            curl -fsSL "https://raw.githubusercontent.com/ProjectSkyfire/SkyFire_548/${SKYFIRE_REF}/sql/base/auth_database.sql" -o "$AUTH_SQL"
        fi
    fi
    echo "--> [Auth] Importando esquema auth..."
    $MYSQL_CMD auth < "$AUTH_SQL"
    echo "--> [Auth] auth_database.sql importado con éxito."
else
    echo "--> [Auth] Ya contiene $AUTH_TABLE_COUNT tablas. Se mantiene sin cambios."
fi

# 4. Inicializar Characters Database
CHARS_TABLE_COUNT=$($MYSQL_CMD -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'characters';")
if [ "$CHARS_TABLE_COUNT" -eq 0 ]; then
    echo "--> [Characters] Base de datos vacía. Obteniendo characters_database.sql..."
    CHARS_SQL="$CACHE_DIR/characters_database.sql"
    if [ ! -f "$CHARS_SQL" ]; then
        if [ -f "/opt/skyfire-server/sql/base/characters_database.sql" ]; then
            cp "/opt/skyfire-server/sql/base/characters_database.sql" "$CHARS_SQL"
        else
            echo "    Descargando characters_database.sql desde GitHub ($SKYFIRE_REF)..."
            curl -fsSL "https://raw.githubusercontent.com/ProjectSkyfire/SkyFire_548/${SKYFIRE_REF}/sql/base/characters_database.sql" -o "$CHARS_SQL"
        fi
    fi
    echo "--> [Characters] Importando esquema characters..."
    $MYSQL_CMD characters < "$CHARS_SQL"
    echo "--> [Characters] characters_database.sql importado con éxito."
else
    echo "--> [Characters] Ya contiene $CHARS_TABLE_COUNT tablas. Se mantiene sin cambios."
fi

# 5. Inicializar World Database (SFDB)
WORLD_TABLE_COUNT=$($MYSQL_CMD -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'world';")
if [ "$WORLD_TABLE_COUNT" -eq 0 ]; then
    echo "--> [World] Base de datos 'world' vacía. Verificando dump de SFDB..."
    
    # Buscar si existe un archivo .sql local en /local_sql
    LOCAL_WORLD_SQL=$(find /local_sql -maxdepth 2 -name "*.sql" -print -quit 2>/dev/null)
    
    if [ -n "$LOCAL_WORLD_SQL" ] && [ -f "$LOCAL_WORLD_SQL" ]; then
        echo "--> [World] Se encontró archivo local: $LOCAL_WORLD_SQL. Importando..."
        $MYSQL_CMD world < "$LOCAL_WORLD_SQL"
    else
        # Buscar en cache o descargar
        WORLD_SQL=$(find "$CACHE_DIR" -maxdepth 1 -name "*.sql" -print -quit 2>/dev/null)
        if [ -z "$WORLD_SQL" ]; then
            echo "--> [World] No se encontró SQL local. Obteniendo release de SFDB desde Codeberg..."
            
            # Obtener URL del release (por env o API)
            DOWNLOAD_URL="${SFDB_DOWNLOAD_URL}"
            if [ -z "$DOWNLOAD_URL" ]; then
                echo "    Consultando API de Codeberg para obtener el release más reciente..."
                DOWNLOAD_URL=$(curl -fsSL https://codeberg.org/api/v1/repos/ProjectSkyfire/database/releases | grep -o 'https://[^"]*SFDB_full_548[^"]*\.zip' | head -n 1 || true)
            fi

            if [ -z "$DOWNLOAD_URL" ]; then
                DOWNLOAD_URL="https://codeberg.org/ProjectSkyfire/database/releases/download/R24.001/SFDB_full_548_24.001_2024_09_04_Release.zip"
            fi

            echo "    Descargando $DOWNLOAD_URL ..."
            ZIP_PATH="$CACHE_DIR/sfdb.zip"
            curl -fSL "$DOWNLOAD_URL" -o "$ZIP_PATH"

            echo "    Descomprimiendo release de base de datos..."
            unzip -q -o "$ZIP_PATH" -d "$CACHE_DIR"
            rm -f "$ZIP_PATH"
            
            WORLD_SQL=$(find "$CACHE_DIR" -maxdepth 1 -name "*.sql" -print -quit 2>/dev/null)
        fi

        if [ -n "$WORLD_SQL" ] && [ -f "$WORLD_SQL" ]; then
            echo "--> [World] Importando $WORLD_SQL en base de datos world (esto puede tardar unos minutos)..."
            $MYSQL_CMD world < "$WORLD_SQL"
            echo "--> [World] SFDB importado exitosamente."
        else
            echo "ERROR: No se pudo localizar el archivo SQL de la base de datos world."
            exit 1
        fi
    fi
else
    echo "--> [World] Ya contiene $WORLD_TABLE_COUNT tablas. Se mantiene sin cambios."
fi

# 6. Actualizar / Insertar Realm en auth.realmlist
echo "--> [Realmlist] Verificando y configurando realm en auth.realmlist..."
$MYSQL_CMD auth -e "
INSERT INTO realmlist (id, name, address, localAddress, localSubnetMask, port, icon, flag, timezone, allowedSecurityLevel, population, gamebuild)
VALUES (1, '$REALM_NAME', '$REALM_ADDRESS', '127.0.0.1', '255.255.255.0', $REALM_PORT, 0, 0, 1, 0, 0, 18414)
ON DUPLICATE KEY UPDATE
  name = '$REALM_NAME',
  address = '$REALM_ADDRESS',
  port = $REALM_PORT,
  gamebuild = 18414;
"

echo "=========================================================="
echo "    [SkyFire DB-Init] Proceso completado exitosamente    "
echo "=========================================================="
