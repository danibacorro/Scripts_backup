# Scripts Tarea backup basado en systemd.

En esta tarea se han creado tres scripts diferentes:  

**Backup_FULL.sh**  
Realiza backups FULL, comprobando ejecución por root, espacio disponible, añadiendo fecha, guardando estado de paquetes, borrando incrementales de más de dos meses de antigüedad y guardando logs.  

**Backup_INC.sh**  
Realiza backups de tipo INCREMENTAL, comprobando ejecución por usuario root, espacio disponible, añadiendo fecha, guardando estado de paquetes y guardando logs.  

**Script_RES.sh**  
Restaura una copia de seguridad (FULL o incremental (INC)) desde un disco de backups a otro disco montado (por ejemplo, desde /mnt/backups a /mnt/sistema) y restaura a paquetería.


