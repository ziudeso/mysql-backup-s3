#! /bin/bash

set -eux
# set -o pipefail

# Update package list
apt-get update

# Install basic tools
apt-get install -y curl wget unzip

# Install MySQL client
apt-get install -y mysql-client

# Install GPG
apt-get install -y gnupg

# Install AWS CLI v2 based on architecture
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
else
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
fi
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install go-cron
ARCH=$(dpkg --print-architecture)
curl -L "https://github.com/ivoronin/go-cron/releases/download/v0.0.5/go-cron_0.0.5_linux_${ARCH}.tar.gz" -o go-cron.tar.gz
tar xvf go-cron.tar.gz
rm go-cron.tar.gz
mv go-cron /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron

# Cleanup
apt-get remove -y unzip
apt-get clean
rm -rf /var/lib/apt/lists/*
