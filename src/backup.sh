#!/bin/bash

set -x  # Abilita il debug

# Carica la configurazione dell'ambiente
source /env.sh

# Verifica che la variabile DATABASES_TO_BACKUP sia impostata
if [ -z "$DATABASES_TO_BACKUP" ]; then
    echo "Errore: DATABASES_TO_BACKUP non è impostata"
    exit 1
fi

echo "Database da backuppare: $DATABASES_TO_BACKUP"

# Funzione per verificare se un database esiste
check_database_exists() {
    local db_name=$1
    mysql --host=$MYSQL_HOST \
          --port=$MYSQL_PORT \
          --user=$MYSQL_USER \
          --password=$MYSQL_PASSWORD \
          -e "USE ${db_name}" 2>/dev/null
    return $?
}

# Funzione per eseguire il backup di un singolo database
backup_database() {
    local db_name=$1
    
    echo "Verifico esistenza del database: $db_name"
    if ! check_database_exists "$db_name"; then
        echo "Errore: Il database $db_name non esiste"
        return 1
    fi
    
    echo "Iniziando backup del database: $db_name"
    
    # Imposta il nome del file di backup
    NOW=$(date +"%Y%m%d_%H%M%S")
    BACKUP_NAME="${db_name}_${NOW}"
    BACKUP_PATH="/tmp/${BACKUP_NAME}"

    # Esegui il backup
    echo "Creazione backup MySQL per $db_name..."
    mysqldump --host=$MYSQL_HOST \
        --port=$MYSQL_PORT \
        --user=$MYSQL_USER \
        --password=$MYSQL_PASSWORD \
        --add-drop-table \
        --no-tablespaces \
        --complete-insert \
        --column-statistics=0 \
        --default-character-set=utf8mb4 \
        "$db_name" > "${BACKUP_PATH}.sql"

    # Verifica il risultato di mysqldump
    DUMP_STATUS=$?
    if [ $DUMP_STATUS -ne 0 ]; then
        echo "Errore in mysqldump per $db_name (codice: $DUMP_STATUS)"
        cat "${BACKUP_PATH}.sql"
        return 1
    fi

    echo "Dimensione del dump SQL originale:"
    ls -lh "${BACKUP_PATH}.sql"

    # Comprimi e opzionalmente cripta
    if [ -n "$PASSPHRASE" ]; then
        echo "Compressione e crittografia del backup..."
        cat "${BACKUP_PATH}.sql" | gzip > "${BACKUP_PATH}.sql.gz"
        gpg --batch --yes --passphrase "$PASSPHRASE" -c "${BACKUP_PATH}.sql.gz"
        FINAL_BACKUP="${BACKUP_PATH}.sql.gz.gpg"
    else
        echo "Compressione del backup..."
        gzip "${BACKUP_PATH}.sql"
        FINAL_BACKUP="${BACKUP_PATH}.sql.gz"
    fi

    # Carica su S3
    echo "Caricamento su S3..."
    S3_PATH="backup/${db_name}/${BACKUP_NAME}$([ -n "$PASSPHRASE" ] && echo ".sql.gz.gpg" || echo ".sql.gz")"
    aws s3 cp "$FINAL_BACKUP" "s3://${S3_BUCKET}/${S3_PATH}"
    
    # Pulisci i backup vecchi per questo database
    if [ -n "$BACKUP_KEEP_DAYS" ]; then
        echo "Rimozione backup più vecchi di $BACKUP_KEEP_DAYS giorni per $db_name..."
        OLDER_THAN=$(date -d "-${BACKUP_KEEP_DAYS} days" +%Y-%m-%d)
        aws s3 ls "s3://${S3_BUCKET}/backup/${db_name}/" | while read -r line; do
            if [[ $line =~ ([0-9]{8}_[0-9]{6}) ]]; then
                FILE_DATE="${BASH_REMATCH[1]}"
                if [[ "$FILE_DATE" < "$OLDER_THAN" ]]; then
                    FILE_NAME=$(echo "$line" | awk '{print $4}')
                    aws s3 rm "s3://${S3_BUCKET}/backup/${db_name}/${FILE_NAME}"
                fi
            fi
        done
    fi

    # Rimuovi i file temporanei
    rm -f "${BACKUP_PATH}.sql" "${BACKUP_PATH}.sql.gz" "${BACKUP_PATH}.sql.gz.gpg"
    
    echo "Backup completato per $db_name"
}

# Debug: mostra le variabili d'ambiente
echo "DATABASES_TO_BACKUP: $DATABASES_TO_BACKUP"
echo "MYSQL_HOST: $MYSQL_HOST"
echo "MYSQL_PORT: $MYSQL_PORT"
echo "MYSQL_USER: $MYSQL_USER"

# Itera su tutti i database nella lista
IFS=',' read -ra DBS <<< "$DATABASES_TO_BACKUP"
for db in "${DBS[@]}"; do
    # Rimuovi eventuali spazi
    db=$(echo "$db" | tr -d ' ')
    echo "Processando database: $db"
    backup_database "$db"
done

echo "Processo di backup completato per tutti i database"
