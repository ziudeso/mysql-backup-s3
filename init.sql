CREATE USER IF NOT EXISTS 'backup_user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
GRANT ALL PRIVILEGES ON test.* TO 'backup_user'@'%';
GRANT PROCESS ON *.* TO 'backup_user'@'%';
FLUSH PRIVILEGES; 