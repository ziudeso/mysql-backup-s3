#!/bin/bash

# Verifica se è stato impostato uno schedule
if [ -z "$SCHEDULE" ]; then
    echo "Nessuno schedule impostato. Eseguo un backup singolo."
    /bin/bash backup.sh
    exit 0
fi

# Verifica se DATABASES_TO_BACKUP è impostato
if [ -z "$DATABASES_TO_BACKUP" ]; then
    echo "Errore: DATABASES_TO_BACKUP non è impostato"
    exit 1
fi

echo "Database da backuppare: $DATABASES_TO_BACKUP"

# Esegui il primo backup immediatamente
echo "Esecuzione backup iniziale..."
/bin/bash backup.sh

# Avvia il cron per i backup successivi
echo "Avvio schedulazione: $SCHEDULE"
exec go-cron "$SCHEDULE" /bin/bash backup.sh
