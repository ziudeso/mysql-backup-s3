#!/bin/bash

# Abilita il debug
set -x

# Carica la configurazione dell'ambiente
. /env.sh

DB_NAME=$MYSQL_DATABASE
TIMESTAMP=$1

# Se non è stato specificato un timestamp, trova l'ultimo backup disponibile
if [ -z "$TIMESTAMP" ]; then
    echo "Nessun timestamp specificato, cerco l'ultimo backup disponibile..."
    BACKUP_NAME=$(
        aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" \
        | grep ".sql.gz.gpg$" \
        | sort \
        | tail -n 1 \
        | awk '{print $4}'
    )
    if [ -z "$BACKUP_NAME" ]; then
        echo "Nessun backup trovato in s3://${S3_BUCKET}/${S3_PREFIX}/"
        echo "Lista dei backup disponibili:"
        aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/"
        exit 1
    fi
    echo "Trovato backup più recente: $BACKUP_NAME"
    BACKUP_FILE="${S3_PREFIX}/${BACKUP_NAME}"
else
    # Verifica che il timestamp sia nel formato corretto
    if ! [[ $TIMESTAMP =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        echo "Errore: il timestamp deve essere nel formato YYYYMMDD_HHMMSS"
        echo "Esempio: 20250121_151906"
        echo "Lista dei backup disponibili:"
        aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/"
        exit 1
    fi
    
    # Costruisci il nome del file di backup
    BACKUP_FILE="${S3_PREFIX}/${DB_NAME}_${TIMESTAMP}.sql.gz.gpg"
fi

# Verifica che il file esista su S3
if ! aws s3 ls "s3://${S3_BUCKET}/${BACKUP_FILE}" > /dev/null 2>&1; then
    echo "Errore: backup non trovato in s3://${S3_BUCKET}/${BACKUP_FILE}"
    echo "Lista dei backup disponibili:"
    aws s3 ls "s3://${S3_BUCKET}/${BACKUP_FILE}"
    exit 1
fi

# Ottieni la dimensione del backup
BACKUP_SIZE=$(aws s3 ls "s3://${S3_BUCKET}/${BACKUP_FILE}" | awk '{print $3}')
echo "Dimensione attesa del backup: $BACKUP_SIZE bytes"

# Imposta i file temporanei
TEMP_FILE="/tmp/restore.sql.gz"
TEMP_SQL="/tmp/restore.sql"

# Download del backup da S3
echo "Download backup da S3..."
if ! aws s3 cp "s3://${S3_BUCKET}/${BACKUP_FILE}" "$TEMP_FILE"; then
    echo "Errore nel download del backup"
    exit 1
fi

# Decripta e decomprimi
if [ -n "$PASSPHRASE" ]; then
    echo "Decriptazione backup..."
    gpg --batch --yes --passphrase "$PASSPHRASE" -d "$TEMP_FILE" > "${TEMP_FILE}.dec"
    mv "${TEMP_FILE}.dec" "$TEMP_FILE"
fi

echo "Decompressione backup..."
gunzip -f "$TEMP_FILE"

# Ripristina il database
echo "Ripristino database..."
mysql --host="$MYSQL_HOST" \
      --port="$MYSQL_PORT" \
      --user="$MYSQL_USER" \
      --password="$MYSQL_PASSWORD" \
      "$DB_NAME" < "$TEMP_SQL"

# Pulisci i file temporanei
rm -f "$TEMP_FILE" "$TEMP_SQL"

echo "Ripristino completato con successo"

# Disabilita il debug
set +x
