# MariaDB 10
# docker buildx build --tag ziudeso/mysql-backup-s3:10 --platform linux/amd64,linux/arm64 --build-arg MARIADB_VERSION=10 .
# docker push ziudeso/mysql-backup-s3:10

# MariaDB 11
# docker buildx build --tag ziudeso/mysql-backup-s3:11 --platform linux/amd64,linux/arm64 --build-arg MARIADB_VERSION=11 .
# docker push ziudeso/mysql-backup-s3:11
# ARG MARIADB_VERSION=11
# FROM mariadb:${MARIADB_VERSION}
FROM ubuntu:22

ADD src/install.sh install.sh
RUN sh install.sh && rm install.sh

ENV MYSQL_DATABASE=''
ENV MYSQL_HOST=''
ENV MYSQL_PORT=3306
ENV MYSQL_USER=''
ENV MYSQL_PASSWORD=''
ENV MYSQLDUMP_EXTRA_OPTS=''
ENV S3_ACCESS_KEY_ID=''
ENV S3_SECRET_ACCESS_KEY=''
ENV S3_BUCKET=''
ENV S3_REGION='eu-central-1'
ENV S3_PREFIX=''
ENV S3_ENDPOINT=''
ENV S3_S3V4='no'
ENV SCHEDULE=''
ENV PASSPHRASE=''
ENV BACKUP_KEEP_DAYS=''

ADD src/run.sh run.sh
ADD src/env.sh env.sh
ADD src/backup.sh backup.sh
ADD src/restore.sh restore.sh

CMD ["sh", "run.sh"]
