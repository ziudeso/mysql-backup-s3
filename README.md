# MySQL Backup to S3
Docker images for automated MySQL database backups to AWS S3 with restore capabilities.

## Features
- Supports MariaDB 10 and 11
- Automated periodic backups to S3
- GPG encryption support
- Backup rotation with automatic cleanup
- Restore from specific timestamps
- WordPress-ready configuration

## Quick Start
```yaml
services:
  mysql-backup:
    build: .
    environment:
      # AWS Configuration
      - AWS_ACCESS_KEY_ID=your_key
      - AWS_SECRET_ACCESS_KEY=your_secret
      - AWS_DEFAULT_REGION=eu-central-1
      - S3_BUCKET=your-bucket
      - S3_PREFIX=backup/database_name
      
      # MySQL Configuration
      - MYSQL_HOST=db-host
      - MYSQL_DATABASE=dbname
      - MYSQL_USER=user
      - MYSQL_PASSWORD=password
      - MYSQL_PORT=3306
      
      # Backup Settings
      - SCHEDULE=@every 1h
      - BACKUP_KEEP_DAYS=14
      - PASSPHRASE=your_encryption_key
```

## Environment Variables

### Required Variables
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `S3_BUCKET`: S3 bucket name
- `MYSQL_HOST`: Database host
- `MYSQL_DATABASE`: Database name
- `MYSQL_USER`: Database user
- `MYSQL_PASSWORD`: Database password

### Optional Variables
- `AWS_DEFAULT_REGION`: AWS region (default: eu-central-1)
- `S3_PREFIX`: Prefix for S3 backup path
- `MYSQL_PORT`: Database port (default: 3306)
- `SCHEDULE`: Backup frequency using go-cron syntax
- `BACKUP_KEEP_DAYS`: Number of days to keep backups
- `PASSPHRASE`: Encryption key for GPG

## Backup Schedule Examples
- `@every 1h`: Every hour
- `@every 30m`: Every 30 minutes
- `@daily`: Once a day at midnight
- `@weekly`: Once a week
- Leave empty for single backup

## Manual Operations

### Trigger Manual Backup
```bash
docker exec <container_name> bash backup.sh
```

### Restore Latest Backup
```bash
docker exec <container_name> bash restore.sh
```

### Restore Specific Backup
```bash
docker exec <container_name> bash restore.sh YYYYMMDD_HHMMSS
```

## Development

### Build Image
```bash
docker compose build --no-cache
```

### Test Environment
```bash
# Copy and edit environment variables
cp .env.example .env

# Start services
docker compose up -d
```

## Security Notes
- Always use encryption for sensitive data
- Store credentials securely
- Use IAM roles with minimal required permissions
- Regularly rotate backup encryption keys

## Limitations
- S3 listing is limited to 1000 files
- Restore operation overwrites existing database

## License
MIT License

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
