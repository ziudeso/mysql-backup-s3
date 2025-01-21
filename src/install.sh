#! /bin/bash

set -eux
# set -o pipefail

# Update package list
apt-get update

# Install MySQL client
apt-get install -y mysql-client

# Install GPG
apt-get install -y gnupg

# Install Python and pip for AWS CLI installation
apt-get install -y python3 python3-pip

# Install AWS CLI
pip3 install --break-system-packages --no-cache-dir --upgrade awscli

# Install go-cron
apt-get install -y curl
curl -L https://github.com/ivoronin/go-cron/releases/download/v0.0.5/go-cron_0.0.5_linux_$(dpkg --print-architecture).tar.gz -O
tar xvf go-cron_0.0.5_linux_$(dpkg --print-architecture).tar.gz
rm go-cron_0.0.5_linux_$(dpkg --print-architecture).tar.gz
mv go-cron /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron
apt-get remove -y curl

# Cleanup
apt-get clean
rm -rf /var/lib/apt/lists/*

# #! /bin/sh

# set -eux
# set -o pipefail

# apk update

# # install mysql-client from the community repository
# echo "http://dl-cdn.alpinelinux.org/alpine/v3.16/community" >> /etc/apk/repositories
# apk add mysql-client

# # install gpg
# apk add gnupg

# apk add aws-cli

# # install go-cron
# apk add curl
# curl -L https://github.com/ivoronin/go-cron/releases/download/v0.0.5/go-cron_0.0.5_linux_${TARGETARCH}.tar.gz -O
# tar xvf go-cron_0.0.5_linux_${TARGETARCH}.tar.gz
# rm go-cron_0.0.5_linux_${TARGETARCH}.tar.gz
# mv go-cron /usr/local/bin/go-cron
# chmod u+x /usr/local/bin/go-cron
# apk del curl

# # cleanup
# rm -rf /var/cache/apk/*
