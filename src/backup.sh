#!/bin/bash

# Abilita il debug
set -x

# Carica la configurazione dell'ambiente
. /env.sh

# Verifica che le variabili necessarie siano impostate
if [ -z "$MYSQL_DATABASE" ]; then
    echo "Errore: MYSQL_DATABASE non è impostato"
    exit 1
fi

# Imposta il nome del file di backup
NOW=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="${MYSQL_DATABASE}_${NOW}"
BACKUP_PATH="/tmp/${BACKUP_NAME}"

# Test connessione MySQL
echo "Test connessione MySQL..."
if ! mysql --host="$MYSQL_HOST" \
    --port="$MYSQL_PORT" \
    --user="$MYSQL_USER" \
    --password="$MYSQL_PASSWORD" \
    -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DATABASE';" > /dev/null; then
    echo "Errore: impossibile connettersi al database"
    exit 1
fi

# Conta le tabelle nel database
TABLE_COUNT=$(mysql --host="$MYSQL_HOST" \
    --port="$MYSQL_PORT" \
    --user="$MYSQL_USER" \
    --password="$MYSQL_PASSWORD" \
    -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DATABASE';")

echo "Numero di tabelle nel database: $TABLE_COUNT"

# Esegui il backup
echo "Creazione backup MySQL..."
mysqldump --host="$MYSQL_HOST" \
    --port="$MYSQL_PORT" \
    --user="$MYSQL_USER" \
    --password="$MYSQL_PASSWORD" \
    --add-drop-database \
    --add-drop-table \
    --add-locks \
    --create-options \
    --disable-keys \
    --extended-insert \
    --no-tablespaces \
    --quick \
    --routines \
    --set-charset \
    --triggers \
    --complete-insert \
    --column-statistics=0 \
    --default-character-set=utf8mb4 \
    --databases "$MYSQL_DATABASE" > "${BACKUP_PATH}.sql"

DUMP_STATUS=$?
if [ $DUMP_STATUS -ne 0 ]; then
    echo "Errore in mysqldump (codice: $DUMP_STATUS)"
    cat "${BACKUP_PATH}.sql"
    exit 1
fi

# Verifica la dimensione del backup non compresso
BACKUP_SIZE=$(stat -f%z "${BACKUP_PATH}.sql" 2>/dev/null || stat -c%s "${BACKUP_PATH}.sql")
echo "Dimensione backup non compresso: $BACKUP_SIZE bytes ($(echo "scale=2; $BACKUP_SIZE/1024" | bc)KB)"

if [ "$BACKUP_SIZE" -lt 100000 ]; then  # Meno di 100KB
    echo "ATTENZIONE: Il backup sembra troppo piccolo ($BACKUP_SIZE bytes)"
    echo "Contenuto del backup:"
    cat "${BACKUP_PATH}.sql"
    exit 1
fi

# Mostra statistiche del backup
echo "Statistiche del backup:"
echo "Numero di tabelle nel dump:"
grep -c "CREATE TABLE" "${BACKUP_PATH}.sql"
echo "Numero di righe INSERT:"
grep -c "INSERT INTO" "${BACKUP_PATH}.sql"

# Comprimi
echo "Compressione del backup..."
cat "${BACKUP_PATH}.sql" | gzip > "${BACKUP_PATH}.sql.gz"
COMPRESSED_SIZE=$(stat -f%z "${BACKUP_PATH}.sql.gz" 2>/dev/null || stat -c%s "${BACKUP_PATH}.sql.gz")
echo "Dimensione dopo compressione: $COMPRESSED_SIZE bytes ($(echo "scale=2; $COMPRESSED_SIZE/1024" | bc)KB)"

# Cripta
if [ -n "$PASSPHRASE" ]; then
    echo "Crittografia del backup..."
    gpg --batch --yes --passphrase "$PASSPHRASE" -c "${BACKUP_PATH}.sql.gz"
    ENCRYPTED_SIZE=$(stat -f%z "${BACKUP_PATH}.sql.gz.gpg" 2>/dev/null || stat -c%s "${BACKUP_PATH}.sql.gz.gpg")
    echo "Dimensione dopo crittografia: $ENCRYPTED_SIZE bytes ($(echo "scale=2; $ENCRYPTED_SIZE/1024" | bc)KB)"
    FINAL_BACKUP="${BACKUP_PATH}.sql.gz.gpg"
else
    FINAL_BACKUP="${BACKUP_PATH}.sql.gz"
fi

echo "Riepilogo dimensioni:"
echo "- Non compresso: $(echo "scale=2; $BACKUP_SIZE/1024" | bc)KB"
echo "- Compresso: $(echo "scale=2; $COMPRESSED_SIZE/1024" | bc)KB"
if [ -n "$PASSPHRASE" ]; then
    echo "- Crittografato: $(echo "scale=2; $ENCRYPTED_SIZE/1024" | bc)KB"
fi

# Carica su S3
echo "Caricamento su S3..."
# Costruisci il path S3 in modo più controllato
FILENAME="${BACKUP_NAME}$([ -n "$PASSPHRASE" ] && echo ".sql.gz.gpg" || echo ".sql.gz")"
# Rimuovi gli slash in eccesso e assicurati che non ci siano slash dopo il prefisso
S3_PATH="${S3_PREFIX}/${FILENAME}"

aws s3 cp "$FINAL_BACKUP" "s3://${S3_BUCKET}/${S3_PATH}"

# Pulizia backup vecchi in modo silenzioso
if [ -n "$BACKUP_KEEP_DAYS" ]; then
    OLDER_THAN=$(date -d "-${BACKUP_KEEP_DAYS} days" +%Y-%m-%d)
    aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/${DB_NAME}/" | while read -r line; do
        if [[ $line =~ ([0-9]{8}_[0-9]{6}) ]]; then
            FILE_DATE="${BASH_REMATCH[1]}"
            if [[ "$FILE_DATE" < "$OLDER_THAN" ]]; then
                FILE_NAME=$(echo "$line" | awk '{print $4}')
                aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/${DB_NAME}/${FILE_NAME}" >/dev/null 2>&1
            fi
        fi
    done
fi

# Rimuovi i file temporanei
rm -f "${BACKUP_PATH}.sql" "${BACKUP_PATH}.sql.gz" "${BACKUP_PATH}.sql.gz.gpg"

echo "Backup completato con successo"
