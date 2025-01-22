-- Creazione utente backup
CREATE USER IF NOT EXISTS 'backup_user'@'%' IDENTIFIED BY 'password';

-- Creazione database WordPress
CREATE DATABASE IF NOT EXISTS wp1_db;
CREATE DATABASE IF NOT EXISTS wp2_db;

-- Modifica permessi per root (già esistente)
GRANT ALL PRIVILEGES ON wp1_db.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON wp2_db.* TO 'root'@'%';

-- Permessi per backup_user
GRANT ALL PRIVILEGES ON test.* TO 'backup_user'@'%';
GRANT PROCESS ON *.* TO 'backup_user'@'%';
GRANT ALL PRIVILEGES ON wp1_db.* TO 'backup_user'@'%';
GRANT ALL PRIVILEGES ON wp2_db.* TO 'backup_user'@'%';

FLUSH PRIVILEGES; 