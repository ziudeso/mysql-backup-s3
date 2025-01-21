#!/bin/bash

# Carica la configurazione dell'ambiente
source /env.sh

# Imposta il nome del file di backup
NOW=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="${MYSQL_DATABASE}_${NOW}.sql.gz"
BACKUP_PATH="/tmp/${BACKUP_NAME}"

# Esegui il backup
echo "Creazione backup MySQL..."
mysqldump --host=$MYSQL_HOST \
    --port=$MYSQL_PORT \
    --user=$MYSQL_USER \
    --password=$MYSQL_PASSWORD \
    $MYSQL_DATABASE 2>/dev/null | gzip > $BACKUP_PATH

# Verifica se il backup è stato creato
if [ ! -f "$BACKUP_PATH" ]; then
    echo "Errore nella creazione del backup"
    exit 1
fi

# Carica su S3
echo "Caricamento su S3..."
aws s3 cp "$BACKUP_PATH" "s3://${S3_BUCKET}/${S3_PREFIX}/${BACKUP_NAME}"

# Pulisci i backup vecchi
if [ -n "$BACKUP_KEEP_DAYS" ]; then
    echo "Rimozione backup più vecchi di $BACKUP_KEEP_DAYS giorni..."
    OLDER_THAN=$(date -d "-${BACKUP_KEEP_DAYS} days" +%Y-%m-%d)
    aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" | while read -r line; do
        if [[ $line =~ ([0-9]{8}_[0-9]{6}) ]]; then
            FILE_DATE="${BASH_REMATCH[1]}"
            if [[ "$FILE_DATE" < "$OLDER_THAN" ]]; then
                FILE_NAME=$(echo "$line" | awk '{print $4}')
                aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/${FILE_NAME}"
            fi
        fi
    done
fi

# Rimuovi il file locale
rm -f "$BACKUP_PATH"

echo "Backup completato con successo"
