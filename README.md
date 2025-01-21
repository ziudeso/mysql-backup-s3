# Introduzione
Questo progetto fornisce immagini Docker per eseguire backup periodici di un database MySQL su AWS S3 e per ripristinare i backup quando necessario.

# Utilizzo
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
docker exec <nome container> sh restore.sh
```

> [!NOTA]
> Se il tuo bucket ha più di 1000 file, l'ultimo potrebbe non essere ripristinato -- viene utilizzato un solo comando S3 `ls`

### ... da un backup specifico
```sh
docker exec <nome container> sh restore.sh <timestamp>
```

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
