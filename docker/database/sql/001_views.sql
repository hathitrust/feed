CREATE DATABASE IF NOT EXISTS `ht`;
USE `ht`;

-- ht_repository views
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `feed_audit` AS SELECT * FROM `ht_repository`.`feed_audit`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `feed_blacklist` AS SELECT * FROM `ht_repository`.`feed_blacklist`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `feed_ia_arkid` AS SELECT * FROM `ht_repository`.`feed_ia_arkid`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `feed_log` AS SELECT * FROM `ht_repository`.`feed_log`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `feed_premis_events` AS SELECT * FROM `ht_repository`.`feed_premis_events`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `feed_priority` AS SELECT * FROM `ht_repository`.`feed_priority`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `feed_queue` AS SELECT * FROM `ht_repository`.`feed_queue`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `feed_queue_done` AS SELECT * FROM `ht_repository`.`feed_queue_done`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `feed_zephir_items` AS SELECT * FROM `ht_repository`.`feed_zephir_items`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `ht_collection_digitizers` AS SELECT * FROM `ht_repository`.`ht_collection_digitizers`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `ht_collections` AS SELECT * FROM `ht_repository`.`ht_collections`;

-- rights views
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `access_profiles` AS SELECT * FROM `ht_rights`.`access_profiles`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `attributes` AS SELECT * FROM `ht_rights`.`attributes`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `reasons` AS SELECT * FROM `ht_rights`.`reasons`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `sources` AS SELECT * FROM `ht_rights`.`sources`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `rights_current` AS SELECT * FROM `ht_rights`.`rights_current`;
