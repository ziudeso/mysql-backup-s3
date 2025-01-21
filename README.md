# Introduzione
Questo progetto fornisce immagini Docker per eseguire backup periodici di un database MySQL su AWS S3 e per ripristinare i backup quando necessario.

# Utilizzo
## Configurazione
Crea un file `.env` con le tue configurazioni:

```env
# AWS S3 Configuration
S3_ACCESS_KEY=your_access_key
S3_SECRET_KEY=your_secret_key
S3_BUCKET_NAME=your-bucket-name
S3_REGION=eu-central-1

# MySQL Configuration
MYSQL_ROOT_PASSWORD=your_root_password
MYSQL_USER=root
MYSQL_PASSWORD=your_password
MYSQL_DATABASE=admin
MYSQL_PORT=3306
MYSQL_HOST=wp-db

# Backup Configuration
DATABASES_TO_BACKUP=admin,altro_db  # Lista dei database da backuppare

PASSPHRASE=your_encryption_password
```

## Docker Compose
```yaml
services:
  mysql-backup:
    build:
      context: .
      args:
        MARIADB_VERSION: '11'
    environment:
      - AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY}
      - AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY}
      - AWS_DEFAULT_REGION=${S3_REGION}
      - AWS_REGION=${S3_REGION}
      - S3_BUCKET=${S3_BUCKET_NAME}
      # MySQL Configuration
      - MYSQL_HOST=${MYSQL_HOST}
      - DATABASES_TO_BACKUP=${DATABASES_TO_BACKUP}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_PORT=${MYSQL_PORT}
      - SCHEDULE=${SCHEDULE}
      - BACKUP_KEEP_DAYS=${BACKUP_KEEP_DAYS}
      - PASSPHRASE=${PASSPHRASE}
```

- La variabile `DATABASES_TO_BACKUP` nel file `.env` specifica quali database backuppare
- Ogni database avrà la sua directory dedicata su S3: `backup/<nome_database>/`
- Il backup può essere schedulato usando la variabile `SCHEDULE`. Esempi:
  - `@every 30m`: ogni 30 minuti
  - `@hourly`: ogni ora
  - `@daily`: ogni giorno
  - `@weekly`: ogni settimana
- Se viene fornito `PASSPHRASE`, il backup sarà crittografato usando GPG
- `BACKUP_KEEP_DAYS` determina per quanti giorni mantenere i backup su S3

## Backup
```yaml
services:
  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_USER: user
      MYSQL_PASSWORD: password
      MYSQL_DATABASE: test

  backup:
    image: eeshugerman/mysql-backup-s3:8
    environment:
      SCHEDULE: '@weekly'     # opzionale
      BACKUP_KEEP_DAYS: 7     # opzionale
      PASSPHRASE: passphrase  # opzionale
      S3_REGION: region
      S3_ACCESS_KEY_ID: key
      S3_SECRET_ACCESS_KEY: secret
      S3_BUCKET: my-bucket
      S3_PREFIX: backup
      MYSQL_HOST: mysql
      MYSQL_DATABASE: dbname
      MYSQL_USER: user
      MYSQL_PASSWORD: password
```

- Le immagini sono taggate in base alla versione maggiore di MySQL supportata: `5.7` o `8`
- La variabile `SCHEDULE` determina la frequenza dei backup. Vedi la documentazione degli schedule di go-cron [qui](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules). Omettere per eseguire il backup immediatamente e poi uscire.
- Se viene fornito `PASSPHRASE`, il backup sarà crittografato usando GPG.
- Esegui `docker exec <nome container> sh backup.sh` per attivare un backup ad-hoc.
- Se `BACKUP_KEEP_DAYS` è impostato, i backup più vecchi di questo numero di giorni verranno eliminati da S3.
- Imposta `S3_ENDPOINT` se stai utilizzando un provider di storage compatibile con S3 non-AWS.

## Ripristino
> [!ATTENZIONE]
> PERDITA DI DATI! Tutti i dati esistenti nel database verranno sovrascritti.

### ... dall'ultimo backup
```sh
docker exec <nome container> sh restore.sh <nome_database>
```
Per esempio:
```sh
docker exec mysql-backup sh restore.sh admin
```

### ... da un backup specifico
```sh
docker exec <nome container> sh restore.sh <nome_database> <timestamp>
```
Per esempio:
```sh
docker exec mysql-backup sh restore.sh admin 20250121_151906
```

> [!NOTA]
> - Il nome del database è obbligatorio e determina da quale cartella di backup ripristinare
> - Il timestamp è opzionale. Se non specificato, verrà utilizzato l'ultimo backup disponibile
> - I backup sono organizzati in cartelle per database: backup/<nome_database>/
> - Prima di procedere con il ripristino, verrà mostrato un riepilogo e richiesta una conferma

# Sviluppo
## Costruire l'immagine localmente
`ALPINE_VERSION` determina la compatibilità con la versione di MySQL. Vedi [`build-and-push-images.yml`](.github/workflows/build-and-push-images.yml) per il mapping più recente.
```sh
DOCKER_BUILDKIT=1 docker build --build-arg ALPINE_VERSION=3.14 .
```
## Eseguire un ambiente di test semplice con Docker Compose
```sh
cp template.env .env
# compila i tuoi segreti/parametri in .env
docker compose up -d
```

# Riconoscimenti
Questo progetto è un fork e una ristrutturazione di @schickling's [postgres-backup-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-backup-s3) e [postgres-restore-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-restore-s3), adattato per MySQL.

## Obiettivi del fork
Queste modifiche sarebbero state difficili o impossibili da unire nel repository di @schickling o in fork strutturati in modo simile.
  - repository dedicato
  - build automatizzate
  - supporto per multiple versioni di MySQL
  - backup e ripristino con una sola immagine

## Altre modifiche e funzionalità
  - alcune variabili d'ambiente rinominate o rimosse
  - supporto per backup crittografati (protetti da password)
  - supporto per il ripristino da un backup specifico tramite timestamp
  - supporto per la rimozione automatica dei backup vecchi
  - filtro dei backup su S3 per nome database
  - nessuna dipendenza da Python 2
