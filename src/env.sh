#! /bin/bash

# Verifica le variabili d'ambiente necessarie
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "You need to set the AWS_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "You need to set the AWS_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ -z "$S3_BUCKET" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

# Pulisci eventuali caratteri problematici
export AWS_ACCESS_KEY_ID=$(echo -n "$AWS_ACCESS_KEY_ID" | tr -d '[:space:]')
export AWS_SECRET_ACCESS_KEY=$(echo -n "$AWS_SECRET_ACCESS_KEY" | tr -d '[:space:]')
export AWS_DEFAULT_REGION="eu-central-1"

# Verifica la lunghezza delle chiavi
if [ ${#AWS_ACCESS_KEY_ID} -ne 20 ]; then
    echo "ERRORE: AWS_ACCESS_KEY_ID deve essere lunga 20 caratteri"
    exit 1
fi

if [ ${#AWS_SECRET_ACCESS_KEY} -ne 40 ]; then
    echo "ERRORE: AWS_SECRET_ACCESS_KEY deve essere lunga 40 caratteri"
    exit 1
fi

# Rimuovi configurazioni esistenti
rm -rf ~/.aws

# Crea la directory .aws
mkdir -p ~/.aws

# Crea il file di configurazione AWS
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF

cat > ~/.aws/config << EOF
[default]
region=${AWS_DEFAULT_REGION}
output=json
EOF

chmod 600 ~/.aws/credentials ~/.aws/config

# Test semplice
echo "Test accesso a S3..."
if aws s3 ls "s3://${S3_BUCKET}" --region eu-central-1 2>/dev/null; then
    echo "Accesso a S3 riuscito"
else
    echo "Errore nell'accesso a S3"
    exit 1
fi

echo "Configurazione completata"
