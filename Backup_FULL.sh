#!/usr/bin/env bash
# Autor: Daniel Baco
# Fecha de creación: 15/10/25
# Versión: 0.2
# Realiza backups FULL, comprobando ejecución por root, espacio disponible, añadiendo fecha, guardando estado de paquetes, borrando incrementales de más de dos meses de antigüedad y guardando logs.

#-----------------------------------------------
# Zona de declaración de variables

DESTINO="/discos/backups"
FECHA=$(date +%Y%m%d_%H%M%S)
DIR_PAQUETES="/var/paqueteria"
DIR_DEST="$DESTINO/full_$FECHA"
RSYNC_LOG="$DESTINO/rsync_$FECHA.log"

LIBRE_DISCO=$(df -m "$DESTINO" | tail -n 1 | awk '{print $4}') # Obtenemos el espacio libre en MB
LIBRE_MINIMO=800 # 800MB

DIRECTORIOS="/etc /var /home /root /usr/local /opt /srv /boot /etc/apt/sources.list*"

#-----------------------------------------------
# Comprobación root

if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse como root."
  exit 1
fi

#-----------------------------------------------
# Comprobación de espacio disponible en el disco

if [ "$LIBRE_DISCO" -lt "$LIBRE_MINIMO" ]; then
    echo "No hay suficiente espacio disponible para realizar el backup. Se necesitan al menos 800MB disponibles."
    exit 1
fi

#-----------------------------------------------
# Ejecución del backup

clear
echo "===== INICIANDO COPIA DE SEGURIDAD - $FECHA ====="
echo "Destino: $DIR_DEST"

# Guardar lista de paquetes instalados
mkdir -p "$DIR_PAQUETES"
dpkg --get-selections > "$DIR_PAQUETES/paquetes_instalados_$FECHA.txt"
echo "[OK] Lista de paquetes guardada en $DIR_PAQUETES"

# Realización del backup
rsync -aAXv --delete $DIRECTORIOS "$DIR_DEST" > "$RSYNC_LOG" 2>&1

echo "[OK] Log generado en $RSYNC_LOG"
echo "===== FIN DE LA COPIA DE SEGURIDAD - $FECHA ====="

# Limpieza de incrementales > 2 meses
echo "===== LIMPIANDO BACKUPS INCREMENTALES > 2 MESES ====="
find "$DESTINO" -maxdepth 1 -type d -name "inc_*" -mtime +60 -exec rm -rf {} +
echo "===== LIMPIEZA FINALIZADA ====="

exit 0

