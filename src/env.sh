#! /bin/sh

# Verifica le variabili d'ambiente necessarie
if [ -z "$S3_BUCKET" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ -z "$MYSQL_DATABASE" ]; then
  echo "You need to set the MYSQL_DATABASE environment variable."
  exit 1
fi

if [ -z "$MYSQL_HOST" ]; then
  # https://docs.docker.com/network/links/#environment-variables
  if [ -n "$MYSQL_PORT_3306_TCP_ADDR" ]; then
    MYSQL_HOST=$MYSQL_PORT_3306_TCP_ADDR
    MYSQL_PORT=$MYSQL_PORT_3306_TCP_PORT
  else
    echo "You need to set the MYSQL_HOST environment variable."
    exit 1
  fi
fi

if [ -z "$MYSQL_USER" ]; then
  echo "You need to set the MYSQL_USER environment variable."
  exit 1
fi

if [ -z "$MYSQL_PASSWORD" ]; then
  echo "You need to set the MYSQL_PASSWORD environment variable."
  exit 1
fi

# Esporta correttamente le credenziali AWS
export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${S3_REGION:-eu-west-1}"

# Debug delle credenziali
echo "Verifica variabili d'ambiente:"
echo "Access Key ID: ${AWS_ACCESS_KEY_ID}"
echo "Secret Key presente: $([ -n "$AWS_SECRET_ACCESS_KEY" ] && echo "Sì" || echo "No")"
echo "Region: ${AWS_DEFAULT_REGION}"

# Test della configurazione
echo "Test configurazione AWS..."
aws configure list

# Test dei comandi S3
echo "Test ListBucket specifico..."
aws s3 ls s3://${S3_BUCKET}

echo "Test accesso al prefix..."
aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}/

echo "Configurazione completata"
