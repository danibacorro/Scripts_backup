#!/usr/bin/env bash
# Autor: Daniel Baco
# Fecha de creación: 15/10/25
# Versión: 0.2
# Realiza backups INCREMENTAL, comprobando ejecución por root, espacio disponible, añadiendo fecha, guardando estado de paquetes y guardando logs.

#-----------------------------------------------
# Zona de declaración de variables

DESTINO="/discos/backups"
FECHA=$(date +%Y%m%d_%H%M%S)
DIR_PAQUETES="/var/paqueteria"
INC_DIR="$DESTINO/inc_$FECHA"
RSYNC_LOG="$DESTINO/rsync_inc_$FECHA.log"

LIBRE_DISCO=$(df -m "$DESTINO" | tail -n 1 | awk '{print $4}') # Obtenemos el espacio libre en MB
LIBRE_MINIMO=300 # 300MB

DIRECTORIOS="/etc /var /home /root /usr/local /opt /srv /boot /etc/apt/sources.list*"

# Buscar última copia full
ULTIMO_FULL=$(ls -1d "$DESTINO"/full_* 2>/dev/null | sort | tail -n 1)


#-----------------------------------------------
# Comprobación root

if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse como root."
  exit 1
fi

#-----------------------------------------------
# Comprobación de espacio disponible en el disco

if [ "$LIBRE_DISCO" -lt "$LIBRE_MINIMO" ]; then
    echo "No hay suficiente espacio disponible para realizar el backup. Se necesitan al menos 300MB disponibles."
    exit 1
fi

#-----------------------------------------------
# Ejecución del backup

clear
if [ -z "$ULTIMO_FULL" ]; then
    echo "No se ha encontrado ningún backup FULL en el que basarse para esta copia."
    exit 1
fi

echo "===== INICIANDO COPIA DE SEGURIDAD - $FECHA ====="
echo "Destino: $INC_DIR"
echo "Basado en: $ULTIMO_FULL"

# Guardar lista de paquetes instalados
mkdir -p "$DIR_PAQUETES"
dpkg --get-selections > "$DIR_PAQUETES/paquetes_instalados_inc_$FECHA.txt"
echo "[OK] Lista de paquetes guardada en $DIR_PAQUETES"

# Realización del backup
mkdir -p "$INC_DIR"

rsync -aAXv --delete --link-dest="$ULTIMO_FULL" $DIRECTORIOS "$INC_DIR" > "$RSYNC_LOG" 2>&1

echo "[OK] Log generado en $RSYNC_LOG"
echo "===== FIN DE LA COPIA DE SEGURIDAD - $FECHA ====="

exit 0

