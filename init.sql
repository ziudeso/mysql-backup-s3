-- Creazione database WordPress se non esistono
CREATE DATABASE IF NOT EXISTS wp1_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp2_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Assicuriamoci che l'utente root abbia tutti i privilegi
GRANT ALL PRIVILEGES ON wp1_db.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON wp2_db.* TO 'root'@'%';

-- Creazione utente backup con privilegi necessari
CREATE USER IF NOT EXISTS 'backup_user'@'%' IDENTIFIED BY 'password';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON wp1_db.* TO 'backup_user'@'%';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON wp2_db.* TO 'backup_user'@'%';
GRANT PROCESS, RELOAD ON *.* TO 'backup_user'@'%';

FLUSH PRIVILEGES; 