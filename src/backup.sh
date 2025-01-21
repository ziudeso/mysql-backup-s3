#!/bin/bash

set -x  # Abilita il debug

# Carica la configurazione dell'ambiente
source /env.sh

# Imposta il nome del file di backup
NOW=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="${MYSQL_DATABASE}_${NOW}"
BACKUP_PATH="/tmp/${BACKUP_NAME}"

# Esegui il backup
echo "Creazione backup MySQL..."
mysqldump --host=$MYSQL_HOST \
    --port=$MYSQL_PORT \
    --user=$MYSQL_USER \
    --password=$MYSQL_PASSWORD \
    --add-drop-table \
    --no-tablespaces \
    --complete-insert \
    --column-statistics=0 \
    --default-character-set=utf8mb4 \
    $MYSQL_DATABASE > "${BACKUP_PATH}.sql"

# Verifica il risultato di mysqldump
DUMP_STATUS=$?
if [ $DUMP_STATUS -ne 0 ]; then
    echo "Errore in mysqldump (codice: $DUMP_STATUS)"
    # Mostra gli errori di mysqldump
    cat "${BACKUP_PATH}.sql"
    exit 1
fi

echo "Dimensione del dump SQL originale:"
ls -lh "${BACKUP_PATH}.sql"
echo "Prime righe del dump:"
head -n 20 "${BACKUP_PATH}.sql"
echo "Numero di righe nel dump:"
wc -l "${BACKUP_PATH}.sql"

# Comprimi e opzionalmente cripta
if [ -n "$PASSPHRASE" ]; then
    echo "Compressione e crittografia del backup..."
    cat "${BACKUP_PATH}.sql" | gzip > "${BACKUP_PATH}.sql.gz"
    echo "Dimensione dopo compressione:"
    ls -lh "${BACKUP_PATH}.sql.gz"
    
    gpg --batch --yes --passphrase "$PASSPHRASE" -c "${BACKUP_PATH}.sql.gz"
    echo "Dimensione dopo crittografia:"
    ls -lh "${BACKUP_PATH}.sql.gz.gpg"
    FINAL_BACKUP="${BACKUP_PATH}.sql.gz.gpg"
else
    echo "Compressione del backup..."
    gzip "${BACKUP_PATH}.sql"
    echo "Dimensione dopo compressione:"
    ls -lh "${BACKUP_PATH}.sql.gz"
    FINAL_BACKUP="${BACKUP_PATH}.sql.gz"
fi

echo "Dimensione del backup finale:"
ls -lh "$FINAL_BACKUP"

# Carica su S3 nel percorso corretto
echo "Caricamento su S3..."
S3_PATH="${S3_PREFIX:+${S3_PREFIX}/}${BACKUP_NAME}$([ -n "$PASSPHRASE" ] && echo ".sql.gz.gpg" || echo ".sql.gz")"
aws s3 cp "$FINAL_BACKUP" "s3://${S3_BUCKET}/${S3_PATH}"

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

# Rimuovi i file locali
rm -f "${BACKUP_PATH}.sql" "${BACKUP_PATH}.sql.gz" "${BACKUP_PATH}.sql.gz.gpg"

echo "Backup completato con successo"
