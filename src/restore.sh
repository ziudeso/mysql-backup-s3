#!/bin/bash

# Abilita il debug
set -x

# Carica la configurazione dell'ambiente
. /env.sh

# Verifica che sia stato fornito almeno il nome del database
if [ $# -lt 1 ]; then
    echo "Utilizzo: $0 <nome_database> [timestamp]"
    echo "Esempio: $0 admin 20250121_144944"
    echo "Se non viene specificato il timestamp, verrà utilizzato l'ultimo backup disponibile"
    exit 1
fi

DB_NAME="$1"
TIMESTAMP="$2"

# Se è specificato il timestamp, usa quello, altrimenti cerca l'ultimo backup
if [ -n "$TIMESTAMP" ]; then
    BACKUP_NAME="${DB_NAME}_${TIMESTAMP}.sql.gz.gpg"
    echo "Utilizzo il backup specifico: $BACKUP_NAME"
    BACKUP_FILE="backup/${DB_NAME}/${BACKUP_NAME}"
else
    echo "Ricerca dell'ultimo backup disponibile per ${DB_NAME}..."
    BACKUP_NAME=$(
        aws s3 ls "s3://${S3_BUCKET}/backup/${DB_NAME}/" \
        | sort \
        | tail -n 1 \
        | awk '{print $4}'
    )
    if [ -z "$BACKUP_NAME" ]; then
        echo "Nessun backup trovato in s3://${S3_BUCKET}/backup/${DB_NAME}/"
        exit 1
    fi
    echo "Trovato backup più recente: $BACKUP_NAME"
    BACKUP_FILE="backup/${DB_NAME}/${BACKUP_NAME}"
fi

echo "Cercando backup: s3://${S3_BUCKET}/${BACKUP_FILE}"
echo "Dimensione attesa del backup: $(aws s3 ls "s3://${S3_BUCKET}/${BACKUP_FILE}" | awk '{print $3}') bytes"

TEMP_FILE="/tmp/restore.sql.gz"
TEMP_SQL="/tmp/restore.sql"

echo "Download backup da S3..."
if ! aws s3 cp "s3://${S3_BUCKET}/${BACKUP_FILE}" "${TEMP_FILE}"; then
    echo "Errore nel download del backup"
    exit 1
fi

echo "Dimensione del backup scaricato:"
ls -lh "${TEMP_FILE}"

echo "Test decrittazione e decompressione..."
if ! gpg --batch --yes --passphrase "$PASSPHRASE" -d "${TEMP_FILE}" 2>/dev/null | gunzip > "${TEMP_FILE}.sql"; then
    echo "Errore nella decrittazione/decompressione"
    exit 1
fi

echo "Dimensione del file SQL:"
ls -lh "${TEMP_FILE}.sql"

echo "Contenuto del backup (prime 50 righe):"
head -n 50 "${TEMP_FILE}.sql"

echo "Verifica presenza di dati importanti:"
grep "INSERT INTO \`wp_posts\`" "${TEMP_FILE}.sql"

read -p "Vuoi procedere con il ripristino del database ${DB_NAME}? (s/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Ripristino annullato"
    rm -f "${TEMP_FILE}" "${TEMP_FILE}.sql"
    exit 1
fi

echo "Ripristino database ${DB_NAME}..."
echo "Prima svuoto completamente il database..."

# Drop e ricrea il database
mysql --host=$MYSQL_HOST \
    --port=$MYSQL_PORT \
    --user=$MYSQL_USER \
    --password=$MYSQL_PASSWORD \
    -e "DROP DATABASE ${DB_NAME};"

mysql --host=$MYSQL_HOST \
    --port=$MYSQL_PORT \
    --user=$MYSQL_USER \
    --password=$MYSQL_PASSWORD \
    -e "CREATE DATABASE ${DB_NAME};"

if [ -n "$PASSPHRASE" ]; then
    # Decrittazione e ripristino
    echo "Decrittazione e decompressione..."
    gpg --batch --yes --passphrase "$PASSPHRASE" -d "${TEMP_FILE}" 2>/dev/null | \
    gunzip | \
    mysql --host=$MYSQL_HOST \
        --port=$MYSQL_PORT \
        --user=$MYSQL_USER \
        --password=$MYSQL_PASSWORD \
        $DB_NAME

    MYSQL_EXIT_CODE=$?
else
    # Solo decompressione e ripristino
    gunzip < "${TEMP_FILE}" | \
    mysql --host=$MYSQL_HOST \
        --port=$MYSQL_PORT \
        --user=$MYSQL_USER \
        --password=$MYSQL_PASSWORD \
        --default-character-set=utf8mb4 \
        $DB_NAME

    MYSQL_EXIT_CODE=$?
fi

# Verifica il risultato
if [ $MYSQL_EXIT_CODE -eq 0 ]; then
    echo "Ripristino completato con successo"
    echo "Verifica contenuto del database:"
    echo "Contenuto della tabella wp_posts (solo contenuti pubblicati):"
    mysql --host=$MYSQL_HOST \
        --port=$MYSQL_PORT \
        --user=$MYSQL_USER \
        --password=$MYSQL_PASSWORD \
        $DB_NAME -e "SELECT ID, post_title, post_type, post_status, post_date 
                           FROM wp_posts 
                           WHERE post_type IN ('page', 'post') 
                           AND post_status = 'publish' 
                           ORDER BY post_date DESC;"
else
    echo "Errore durante il ripristino (codice: $MYSQL_EXIT_CODE)"
    exit 1
fi

# Pulizia
rm -f "${TEMP_FILE}" "${TEMP_FILE}.sql"

# Disabilita il debug
set +x
