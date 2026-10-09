#!/bin/bash
set -e

MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
SKYFIRE_DB_USER="${SKYFIRE_DB_USER:-skyfire}"
SKYFIRE_DB_PASSWORD="${SKYFIRE_DB_PASSWORD:-skyfire}"
AUTH_DB="${AUTH_DB:-auth}"
WORLD_DB="${WORLD_DB:-world}"
CHARACTERS_DB="${CHARACTERS_DB:-characters}"
DATA_DIR="${DATA_DIR:-/opt/skyfire-server/data}"
LOGS_DIR="${LOGS_DIR:-/opt/skyfire-server/logs}"
CONFIG_DIR="/opt/skyfire-server/etc"

mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOGS_DIR"

echo "=========================================================="
echo "    Iniciando contenedor SkyFire 5.4.8 ($1)              "
echo "=========================================================="

# Esperar a MySQL
echo "==> Verificando conexión a MySQL en $MYSQL_HOST:$MYSQL_PORT..."
MAX_TRIES=60
TRIES=0
while ! nc -z "$MYSQL_HOST" "$MYSQL_PORT"; do
    TRIES=$((TRIES + 1))
    if [ "$TRIES" -ge "$MAX_TRIES" ]; then
        echo "ERROR: Tiempo de espera agotado conectando a MySQL en $MYSQL_HOST:$MYSQL_PORT"
        exit 1
    fi
    echo "    Esperando a que MySQL esté disponible ($TRIES/$MAX_TRIES)..."
    sleep 2
done
echo "==> Conexión a MySQL detectada exitosamente."

# Localizar plantillas .conf.dist si no existen en etc/
find_dist() {
    local name="$1"
    if [ -f "/opt/skyfire-server/etc.default/$name" ]; then
        echo "/opt/skyfire-server/etc.default/$name"
    elif [ -f "$CONFIG_DIR/$name" ]; then
        echo "$CONFIG_DIR/$name"
    elif [ -f "/opt/skyfire-server/bin/$name" ]; then
        echo "/opt/skyfire-server/bin/$name"
    else
        find /opt/skyfire-server -name "$name" -print -quit 2>/dev/null
    fi
}

configure_authserver() {
    local conf="$CONFIG_DIR/authserver.conf"
    if [ ! -f "$conf" ]; then
        local dist
        dist=$(find_dist "authserver.conf.dist")
        if [ -n "$dist" ] && [ -f "$dist" ]; then
            echo "==> Copiando plantilla $dist a $conf..."
            cp "$dist" "$conf"
        else
            echo "ERROR: No se encontró plantilla authserver.conf.dist"
            exit 1
        fi
    fi

    echo "==> Aplicando configuración dinámica en authserver.conf..."
    sed -i -E "s|^[# ]*LoginDatabaseInfo[[:space:]]*=.*|LoginDatabaseInfo = \"${MYSQL_HOST};${MYSQL_PORT};${SKYFIRE_DB_USER};${SKYFIRE_DB_PASSWORD};${AUTH_DB}\"|g" "$conf"
    sed -i -E "s|^[# ]*LogsDir[[:space:]]*=.*|LogsDir = \"${LOGS_DIR}\"|g" "$conf"
    sed -i -E "s|^[# ]*LoginDatabase\.SqlPath[[:space:]]*=.*|LoginDatabase.SqlPath = \"/opt/skyfire-server/sql\"|g" "$conf"
    sed -i -E "s|^[# ]*LoginDatabase\.AutoSetup[[:space:]]*=.*|LoginDatabase.AutoSetup = 1|g" "$conf"
}

configure_worldserver() {
    local conf="$CONFIG_DIR/worldserver.conf"
    if [ ! -f "$conf" ]; then
        local dist
        dist=$(find_dist "worldserver.conf.dist")
        if [ -n "$dist" ] && [ -f "$dist" ]; then
            echo "==> Copiando plantilla $dist a $conf..."
            cp "$dist" "$conf"
        else
            echo "ERROR: No se encontró plantilla worldserver.conf.dist"
            exit 1
        fi
    fi

    echo "==> Aplicando configuración dinámica en worldserver.conf..."
    sed -i -E "s|^[# ]*LoginDatabaseInfo[[:space:]]*=.*|LoginDatabaseInfo = \"${MYSQL_HOST};${MYSQL_PORT};${SKYFIRE_DB_USER};${SKYFIRE_DB_PASSWORD};${AUTH_DB}\"|g" "$conf"
    sed -i -E "s|^[# ]*WorldDatabaseInfo[[:space:]]*=.*|WorldDatabaseInfo = \"${MYSQL_HOST};${MYSQL_PORT};${SKYFIRE_DB_USER};${SKYFIRE_DB_PASSWORD};${WORLD_DB}\"|g" "$conf"
    sed -i -E "s|^[# ]*CharacterDatabaseInfo[[:space:]]*=.*|CharacterDatabaseInfo = \"${MYSQL_HOST};${MYSQL_PORT};${SKYFIRE_DB_USER};${SKYFIRE_DB_PASSWORD};${CHARACTERS_DB}\"|g" "$conf"
    sed -i -E "s|^[# ]*DataDir[[:space:]]*=.*|DataDir = \"${DATA_DIR}\"|g" "$conf"
    sed -i -E "s|^[# ]*LogsDir[[:space:]]*=.*|LogsDir = \"${LOGS_DIR}\"|g" "$conf"
    sed -i -E "s|^[# ]*WorldDatabase\.SqlPath[[:space:]]*=.*|WorldDatabase.SqlPath = \"/opt/skyfire-server/sql\"|g" "$conf"
    sed -i -E "s|^[# ]*CharacterDatabase\.SqlPath[[:space:]]*=.*|CharacterDatabase.SqlPath = \"/opt/skyfire-server/sql\"|g" "$conf"
    sed -i -E "s|^[# ]*WorldDatabase\.AutoSetup[[:space:]]*=.*|WorldDatabase.AutoSetup = 1|g" "$conf"
    sed -i -E "s|^[# ]*CharacterDatabase\.AutoSetup[[:space:]]*=.*|CharacterDatabase.AutoSetup = 1|g" "$conf"
    sed -i -E "s|^[# ]*WorldDatabase\.AutoBaseline[[:space:]]*=.*|WorldDatabase.AutoBaseline = 0|g" "$conf"
    sed -i -E "s|^[# ]*CharacterDatabase\.AutoBaseline[[:space:]]*=.*|CharacterDatabase.AutoBaseline = 0|g" "$conf"
}

case "$1" in
    authserver)
        configure_authserver
        echo "==> Iniciando SkyFire AuthServer..."
        exec /opt/skyfire-server/bin/authserver -c "$CONFIG_DIR/authserver.conf"
        ;;
    worldserver)
        configure_worldserver
        # Detección inteligente si dbc o maps están en una subcarpeta (ej: Data/, server/data/, etc.)
        if [ ! -d "$DATA_DIR/dbc" ] && [ ! -d "$DATA_DIR/maps" ]; then
            NESTED_DIR=$(find "$DATA_DIR" -maxdepth 2 -type d \( -name "dbc" -o -name "maps" \) -print -quit 2>/dev/null)
            if [ -n "$NESTED_DIR" ]; then
                PARENT_DIR=$(dirname "$NESTED_DIR")
                echo "==> Detectados datos de mapas en subcarpeta: $PARENT_DIR. Enlazando..."
                for sub in dbc maps vmaps mmaps; do
                    if [ -d "$PARENT_DIR/$sub" ] && [ ! -e "$DATA_DIR/$sub" ]; then
                        ln -s "$PARENT_DIR/$sub" "$DATA_DIR/$sub"
                    fi
                done
            fi
        fi

        if [ ! -d "$DATA_DIR/dbc" ] && [ ! -d "$DATA_DIR/maps" ]; then
            echo "------------------------------------------------------------------"
            echo "[ADVERTENCIA] No se encontraron carpetas 'dbc' o 'maps' en $DATA_DIR"
            echo "Contenido detectado actualmente en $DATA_DIR:"
            ls -la "$DATA_DIR" 2>/dev/null || echo "(directorio vacío o inaccesible)"
            echo "------------------------------------------------------------------"
        fi
        echo "==> Iniciando SkyFire WorldServer..."
        exec /opt/skyfire-server/bin/worldserver -c "$CONFIG_DIR/worldserver.conf"
        ;;
    *)
        exec "$@"
        ;;
esac
