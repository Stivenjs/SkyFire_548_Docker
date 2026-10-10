#!/usr/bin/env python3
"""
Script dinámico e interactivo para crear cuentas en SkyFire 5.4.8 (MoP).
Calcula la autenticación SRP-6 (salt y verifier) requerida por el cliente
e inserta la cuenta directamente en la base de datos MySQL vía Docker Compose.
"""

import sys
import os
import hashlib
import getpass
import subprocess
from pathlib import Path

# Constantes criptográficas oficiales SRP-6a para TrinityCore / SkyFire
N_HEX = "894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7"
N = int(N_HEX, 16)
G = 7

def find_env_file() -> Path:
    """Busca el archivo .env en el directorio actual o en la raíz del proyecto."""
    script_dir = Path(__file__).resolve().parent
    candidates = [
        script_dir.parent / ".env",
        Path.cwd() / ".env",
        script_dir / ".env",
    ]
    for p in candidates:
        if p.is_file():
            return p
    return script_dir.parent / ".env"

def load_env_vars(env_path: Path) -> dict:
    """Lee variables de entorno desde un archivo .env sin dependencias externas."""
    env = {}
    if env_path.is_file():
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, val = line.split("=", 1)
                    key = key.strip()
                    val = val.strip().strip("'\"")
                    env[key] = val
    return env

def compute_srp6(username: str, password: str, salt: bytes = None) -> tuple[bytes, bytes]:
    """Genera salt y verifier usando SRP-6a con ordenamiento little-endian."""
    if salt is None:
        salt = os.urandom(32)

    u = username.upper().encode("utf-8")
    p = password.upper().encode("utf-8")

    # 1. hashIP = SHA1(UPPER(user) : UPPER(pass))
    h_ip = hashlib.sha1(u + b":" + p).digest()

    # 2. hashX = SHA1(salt + hashIP)
    h_x = hashlib.sha1(salt + h_ip).digest()

    # 3. x = BigInt interpretado en Little-Endian desde hashX
    x = int.from_bytes(h_x, byteorder="little")

    # 4. verifier = g^x % N
    v = pow(G, x, N)

    # 5. Representación en 32 bytes little-endian del verifier
    v_bytes = v.to_bytes(32, byteorder="little")

    return salt, v_bytes

def get_db_credentials() -> tuple[str, str]:
    """Obtiene el usuario y contraseña de MySQL desde variables de entorno o .env."""
    env_path = find_env_file()
    env_vars = load_env_vars(env_path)

    # Priorizar credenciales root si existen
    root_pass = os.environ.get("MYSQL_ROOT_PASSWORD") or env_vars.get("MYSQL_ROOT_PASSWORD")
    if root_pass:
        return "root", root_pass

    # Alternativa: usuario skyfire de la BD
    db_user = os.environ.get("SKYFIRE_DB_USER") or env_vars.get("SKYFIRE_DB_USER", "skyfire")
    db_pass = os.environ.get("SKYFIRE_DB_PASSWORD") or env_vars.get("SKYFIRE_DB_PASSWORD")
    if db_pass:
        return db_user, db_pass

    # Si no se encuentra en ningún lado, solicitar interactivamente
    print("[!] No se encontró contraseña de MySQL en .env ni en variables de entorno.")
    pass_input = getpass.getpass("Ingrese la contraseña de MySQL (root o skyfire): ").strip()
    return "root", pass_input

def create_account(username: str, password: str, gmlevel: int = 0) -> bool:
    """Crea o actualiza la cuenta en la base de datos auth."""
    salt, verifier = compute_srp6(username, password)
    salt_hex = salt.hex()
    verifier_hex = verifier.hex()

    db_user, db_pass = get_db_credentials()

    # Sanitizar username para la consulta SQL
    safe_user = username.replace("'", "''").upper()

    sql = f"""
    USE auth;
    DELETE FROM account WHERE username = '{safe_user}';
    INSERT INTO account (username, salt, verifier, email, expansion)
    VALUES ('{safe_user}', UNHEX('{salt_hex}'), UNHEX('{verifier_hex}'), '{safe_user.lower()}@local', 4);

    SET @acc_id = LAST_INSERT_ID();
    DELETE FROM account_access WHERE id = @acc_id;
    """

    if gmlevel > 0:
        sql += f"""
    INSERT INTO account_access (id, gmlevel, RealmID) VALUES (@acc_id, {gmlevel}, -1);
    """

    sql += """
    SELECT id, username, expansion FROM account WHERE id = @acc_id;
    """
    if gmlevel > 0:
        sql += """
    SELECT id, gmlevel, RealmID FROM account_access WHERE id = @acc_id;
    """

    cmd = [
        "docker", "compose", "exec", "-T", "mysql",
        "mysql", f"-u{db_user}", f"-p{db_pass}", "-e", sql
    ]

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if res.returncode != 0:
            print(f"\n[ERROR] Falló la ejecución en MySQL:\n{res.stderr.strip()}")
            return False

        gm_labels = {
            0: "Jugador normal",
            1: "Moderador",
            2: "Game Master (GM)",
            3: "Desarrollador / Bug Hunter",
            4: "Administrador / GM Supremo"
        }
        label = gm_labels.get(gmlevel, f"Nivel {gmlevel}")

        print("\n=======================================================")
        print(f" [OK] Cuenta '{safe_user}' creada exitosamente!")
        print(f"      - Expansión: Mists of Pandaria (4)")
        print(f"      - Rango: {label} (Nivel {gmlevel})")
        print(f"      - Reinos: Todos (-1)")
        print("=======================================================")
        return True

    except FileNotFoundError:
        print("\n[ERROR] El comando 'docker' no fue encontrado en el PATH del sistema.")
        return False
    except Exception as e:
        print(f"\n[ERROR] Error inesperado al crear la cuenta: {e}")
        return False

def prompt_account_info() -> tuple[str, str, int]:
    """Solicita de forma interactiva y amigable los datos de la cuenta."""
    print("=======================================================")
    print("   SkyFire 5.4.8 — Creador Interactivo de Cuentas     ")
    print("=======================================================")

    while True:
        user = input("\nNombre de usuario: ").strip()
        if user:
            break
        print("El nombre de usuario no puede estar vacío.")

    while True:
        pwd = getpass.getpass("Contraseña: ").strip()
        if not pwd:
            # Si getpass no muestra prompt en ciertas terminales
            pwd = input("Contraseña (visible): ").strip()
        if pwd:
            break
        print("La contraseña no puede estar vacía.")

    print("\nSelecciona el nivel de permisos de la cuenta:")
    print("  0: Jugador normal")
    print("  1: Moderador")
    print("  2: Game Master (GM)")
    print("  3: Desarrollador / Bug Hunter")
    print("  4: Administrador / GM Supremo (Acceso total)")

    while True:
        lvl_str = input("\nNivel GM [0-4] (por defecto 0): ").strip()
        if not lvl_str:
            level = 0
            break
        if lvl_str.isdigit() and 0 <= int(lvl_str) <= 4:
            level = int(lvl_str)
            break
        print("Por favor introduce un número entre 0 y 4.")

    return user, pwd, level

def main():
    # Si se pasan parámetros por línea de comando: python create_account.py <usuario> <pass> [nivel]
    if len(sys.argv) >= 3:
        user = sys.argv[1].strip()
        pwd = sys.argv[2].strip()
        level = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 0
    else:
        # Modo interactivo
        user, pwd, level = prompt_account_info()

    create_account(user, pwd, level)

if __name__ == "__main__":
    main()
