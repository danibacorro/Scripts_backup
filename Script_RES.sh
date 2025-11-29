#!/usr/bin/env bash
# Autor: Daniel Baco
# Fecha de creación: 15/11/25
# Versión: 0.3
# Restaura una copia de seguridad (FULL o incremental (INC)) desde un disco de backups a otro disco montado (por ejemplo, desde /mnt/backups a /mnt/sistema) y restaura a paquetería.

#-----------------------------------------------
# Zona de declaración de variables

BACKUP_SRC="/discos/bk/backups"       # Donde están las copias full_*, inc_*
TARGET_MOUNT="/discos/sys/"     # Donde está montado el sistema dañado
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/restore_external_$(date +%Y%m%d_%H%M%S).log"

#-----------------------------------------------
# Comprobaciones

# Comprobación root
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse como root."
  exit 1
fi

# Comprobación origen
if [ ! -d "$BACKUP_SRC" ]; then
  echo "No se encuentra el directorio de backups: $BACKUP_SRC"
  exit 1
fi

# Comprobación punto de montaje
if [ ! -d "$TARGET_MOUNT" ]; then
  echo "No se encuentra el punto de montaje destino: $TARGET_MOUNT"
  exit 1
fi

#-----------------------------------------------
# Listar copias disponibles

echo "===== COPIAS DE SEGURIDAD DISPONIBLES ====="
ls -1 "$BACKUP_SRC" | grep -E "^(full_|inc_)" | sort
echo "==========================================="


# Seleccionar copia
read -rp "Introduce el nombre del backup a restaurar (por ejemplo: full_20251015_123000 o inc_20251017_123000): " BACKUP_DIR

if [ -z "$BACKUP_DIR" ]; then
  echo "No se ha especificado ningún backup. Saliendo del programa..."
  exit 1
fi

if [ ! -d "$BACKUP_SRC/$BACKUP_DIR" ]; then
  echo "No se encuentra el backup $BACKUP_SRC/$BACKUP_DIR."
  exit 1
fi

#-----------------------------------------------
# Confirmar restauración

echo ""
echo "Este script sobreescribirá los datos de $TARGET_MOUNT con los archivos del backup $BACKUP_DIR."
read -rp "¿Continuar? (y/n): " CONFIRMACION

if [ "$CONFIRMACION" != "y" ]; then
  echo "Restauración cancelada."
  exit 0
fi

#-----------------------------------------------
# Averiguar si el backup elegido es FULL o INC y generar la cadena de restauración

BACKUP_CHAIN=()

if [[ "$BACKUP_DIR" == full_* ]]; then
    echo "Backup FULL seleccionado."
    BACKUP_CHAIN=("$BACKUP_DIR")

else
    echo "Backup INC seleccionado. Buscando FULL base…"

    TS=$(echo "$BACKUP_DIR" | sed 's/inc_//')

    # Buscar backup FULL anterior al INC seleccionado
    FULL_BASE=$(ls "$BACKUP_SRC" | grep "^full_" | sort | awk -v TS="$TS" '
        {
            sub(/^full_/, "", $0);
            if ($0 <= TS) last_full=$0;
        }
        END {
            if (last_full != "") print "full_" last_full;
        }'
    )

    # Si no encuentra un backup FULL fallará
    if [ -z "$FULL_BASE" ]; then
        echo "[ERROR] No se pudo encontrar un backup FULL base."
        exit 1
    fi

    echo "FULL base encontrada: $FULL_BASE"

    # Cadena de restauración formada, primero por backup FULL, luego la INC
    BACKUP_CHAIN=("$FULL_BASE" "$BACKUP_DIR")
fi

# Lista la FULL elegida y la INC en caso de haberse elegido
echo ""
echo "Cadena de restauración final:"
for b in "${BACKUP_CHAIN[@]}"; do
    echo " - $b"
done
echo ""

#-----------------------------------------------
# Ejecución de la restauración

echo "===== INICIANDO RESTAURACIÓN ====="
echo "Log: $LOG_FILE"
echo ""

# Recorre la variable para que en caso de haber FULL e INC restaure ambas
for B in "${BACKUP_CHAIN[@]}"; do
    ORIGEN="$BACKUP_SRC/$B"
    echo "Restaurando desde: $ORIGEN ..."
    echo ">> Restaurando $B..." >> "$LOG_FILE"

    rsync -aAXHv --delete \
      --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} \
      "$ORIGEN"/ "$TARGET_MOUNT"/ \
      >> "$LOG_FILE" 2>&1

    # Si por algún motivo falla, lo envía a un log
    if [ $? -ne 0 ]; then
        echo "[ERROR $(date +%Y-%m-%d\ %H:%M:%S)] Fallo aplicando $B. Revisa el log: $LOG_FILE"
        exit 1
    fi
done

echo ""
echo "[OK] Restauración completada correctamente."

#-----------------------------------------------
# Restauración de paquetería

echo ""
echo "===== RESTAURACIÓN DE PAQUETES ====="

# Extraer fecha del backup seleccionado
FECHA=$(echo "$BACKUP_DIR" | sed 's/^full_//;s/^inc_//')

# Ruta al archivo de lista de paquetes guardado en el backup
PAQUETES_BACKUP="$BACKUP_SRC/$B/paquetes_instalados_$FECHA.txt"

# Verificamos si el archivo de paquetes existe en el backup
if [ -f "$PAQUETES_BACKUP" ]; then
    echo "Lista de paquetes encontrada: $PAQUETES_BACKUP"

    # Leemos la lista de paquetes y la comparamos con los paquetes instalados en el sistema
    INSTALADOS_BACKUP=$(cat "$PAQUETES_BACKUP")
    INSTALADOS_ACTUALES=$(dpkg --get-selections)

    # Comparar los paquetes instalados y aquellos que faltan
    FALTAN_PAQUETES=$(comm -13 <(echo "$INSTALADOS_ACTUALES" | sort) <(echo "$INSTALADOS_BACKUP" | sort))

    if [ -n "$FALTAN_PAQUETES" ]; then
        echo "Instalando paquetes faltantes..."
        echo "$FALTAN_PAQUETES" | while read PAQUETE; do
            apt install -y "$PAQUETE" >> "$LOG_FILE" 2>&1
            if [ $? -ne 0 ]; then
                echo "[ERROR] Fallo al instalar el paquete: $PAQUETE. Revisa el log: $LOG_FILE"
            else
                echo "[OK] Paquete instalado: $PAQUETE" >> "$LOG_FILE"
            fi
        done
    else
        echo "[OK] Todos los paquetes están instalados."
    fi
else
    echo "[ERROR] No se encontró el archivo de lista de paquetes en el backup: $PAQUETES_BACKUP"
    exit 1
fi
echo "===== RESTAURACIÓN DE PAQUETES COMPLETADA ====="
echo "===== FIN DE LA RESTAURACIÓN ====="
exit 0
