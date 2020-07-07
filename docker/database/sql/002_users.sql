
GRANT USAGE ON *.* TO 'ht_repository'@'%' IDENTIFIED BY 'ht_repository';
GRANT SELECT ON `ht_rights`.* TO 'ht_repository'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `ht_repository`.* TO 'ht_repository'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `ht`.* TO 'ht_repository'@'%';
