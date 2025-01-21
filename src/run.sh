#!/bin/bash

# Verifica se è stato impostato uno schedule
if [ -z "$SCHEDULE" ]; then
    echo "Nessuno schedule impostato. Eseguo un backup singolo."
    /bin/bash backup.sh
    exit 0
fi

# Esegui il primo backup immediatamente
echo "Esecuzione backup iniziale..."
/bin/bash backup.sh

# Avvia il cron per i backup successivi
echo "new cron: $SCHEDULE"
exec go-cron "$SCHEDULE" /bin/bash backup.sh
