#! /bin/bash

set -eu
# set -o pipefail

source ./env.sh

echo "Creating backup of $MYSQL_DATABASE database..."
mysqldump \
    -h $MYSQL_HOST \
    -P $MYSQL_PORT \
    -u $MYSQL_USER \
    --password=$MYSQL_PASSWORD \
    $MYSQLDUMP_EXTRA_OPTS \
    $MYSQL_DATABASE \
    > db.dump

# Encrypt backup
echo "Encrypting backup..."
gpg --symmetric --batch --yes --passphrase "$PASSPHRASE" db.dump

# Debug AWS configuration
echo "Verifica configurazione AWS..."
aws configure list

# Test della connessione S3
echo "Test connessione S3..."
aws s3 ls "s3://$S3_BUCKET" || {
    echo "Errore nella connessione a S3. Verifica credenziali e permessi."
    exit 1
}

# Upload to S3 with specific flags
echo "Uploading backup to S3..."
timestamp=$(date +%Y%m%d_%H%M%S)
backup_file="$timestamp.sql.gpg"

aws s3 cp db.dump.gpg "s3://$S3_BUCKET/$S3_PREFIX/$backup_file" \
    --region $S3_REGION \
    --only-show-errors

if [ $? -eq 0 ]; then
    echo "Upload completato con successo: $backup_file"
    # Verifica che il file sia stato caricato
    aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX/$backup_file"
else
    echo "Errore durante l'upload"
    exit 1
fi

# Test di verifica dopo l'upload
echo "Verifica dei backup esistenti..."
aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX/" --recursive

# Cleanup
rm db.dump db.dump.gpg

echo "Backup complete!"

if [ -n "$BACKUP_KEEP_DAYS" ]; then
  sec=$((86400*BACKUP_KEEP_DAYS))
  date_from_remove=$(date -d "@$(($(date +%s) - sec))" +%Y-%m-%d)
  backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

  echo "Removing old backups from $S3_BUCKET..."
  aws s3api list-objects \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX}" \
    --query "${backups_query}" \
    --output text \
    | xargs -n1 -t -I 'KEY' aws s3 rm s3://"${S3_BUCKET}"/'KEY'
  echo "Removal complete."
fi
