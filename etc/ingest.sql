USE `ht`;

CREATE TABLE IF NOT EXISTS `feed_audit` (
  `namespace` varchar(10) NOT NULL,
  `id` varchar(30) NOT NULL,
  `sdr_partition` tinyint(4) DEFAULT NULL,
  `zip_size` bigint(20) DEFAULT NULL,
  `image_size` bigint(20) DEFAULT NULL,
  `zip_date` datetime DEFAULT NULL,
  `mets_size` bigint(20) DEFAULT NULL,
  `mets_date` datetime DEFAULT NULL,
  `page_count` int(11) DEFAULT NULL,
  `lastchecked` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastmd5check` timestamp NULL DEFAULT NULL,
  `md5check_ok` tinyint(1) DEFAULT NULL,
  `is_tombstoned` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`namespace`,`id`),
  KEY `feed_audit_zip_date_idx` (`zip_date`)
);

CREATE TABLE IF NOT EXISTS `feed_queue_disallow` (
  `namespace` varchar(8) NOT NULL DEFAULT '',
  `id` varchar(32) NOT NULL DEFAULT '',
  `note` text,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`namespace`,`id`)
);

CREATE TABLE IF NOT EXISTS `feed_ia_arkid` (
  `ia_id` varchar(255) NOT NULL DEFAULT '',
  `namespace` varchar(32) DEFAULT NULL,
  `arkid` varchar(32) DEFAULT NULL,
  `resolution` varchar(8) DEFAULT NULL,
  PRIMARY KEY (`ia_id`),
  KEY `arkid` (`arkid`)
);

CREATE TABLE IF NOT EXISTS `feed_log` (
  `level` varchar(5) NOT NULL,
  `timestamp` datetime NOT NULL,
  `namespace` varchar(8) DEFAULT NULL,
  `id` varchar(32) DEFAULT NULL,
  `operation` varchar(32) DEFAULT NULL,
  `message` varchar(255) DEFAULT NULL,
  `file` tinytext,
  `field` tinytext,
  `actual` tinytext,
  `expected` tinytext,
  `detail` tinytext,
  `stage` varchar(255) DEFAULT NULL,
  KEY `log_objid_idx` (`namespace`,`id`),
  KEY `log_timestamp_idx` (`timestamp`),
  KEY `log_stage_idx` (`stage`)
);

CREATE TABLE IF NOT EXISTS `feed_premis_events` (
  `namespace` varchar(8) NOT NULL DEFAULT '',
  `id` varchar(32) NOT NULL DEFAULT '',
  `eventtype_id` varchar(64) NOT NULL DEFAULT '',
  `date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `outcome` text,
  `eventid` char(36) DEFAULT NULL,
  `custom_xml` mediumtext,
  PRIMARY KEY (`namespace`,`id`,`eventtype_id`)
);

CREATE TABLE IF NOT EXISTS `feed_priority` (
  `priority` tinyint(3) unsigned DEFAULT '254',
  `pkg_type` varchar(32) DEFAULT NULL,
  `namespace` varchar(8) DEFAULT NULL,
  UNIQUE KEY `nspkg` (`namespace`,`pkg_type`),
  KEY `priority` (`priority`)
);

CREATE TABLE IF NOT EXISTS `feed_queue` (
  `pkg_type` varchar(32) DEFAULT NULL,
  `namespace` varchar(8) NOT NULL DEFAULT '',
  `id` varchar(32) NOT NULL DEFAULT '',
  `status` varchar(20) NOT NULL DEFAULT 'ready',
  `reset_status` varchar(20) DEFAULT NULL,
  `update_stamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `date_added` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `node` varchar(255) DEFAULT NULL,
  `failure_count` int(11) NOT NULL DEFAULT '0',
  `priority` int(11) DEFAULT NULL,
  PRIMARY KEY (`namespace`,`id`),
  KEY `queue_pkg_type_status_idx` (`pkg_type`,`status`),
  KEY `queue_node_idx` (`node`),
  KEY `queue_priority_idx` (`priority`,`date_added`),
  KEY `queue_node_status_index` (`node`,`status`)
);

CREATE TABLE IF NOT EXISTS `feed_queue_done` (
  `pkg_type` varchar(32) DEFAULT NULL,
  `namespace` varchar(8) NOT NULL DEFAULT '',
  `id` varchar(32) NOT NULL DEFAULT '',
  `update_stamp` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `date_added` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`namespace`,`id`)
);

CREATE TABLE IF NOT EXISTS `feed_zephir_items` (
  `namespace` varchar(5) NOT NULL,
  `id` varchar(32) NOT NULL,
  `collection` varchar(32) NOT NULL,
  `digitization_source` varchar(32) NOT NULL,
  `returned` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`namespace`,`id`),
  KEY `collection` (`collection`,`digitization_source`)
);

CREATE TABLE IF NOT EXISTS `feed_backups` (
  `namespace` varchar(10) NOT NULL,
  `id` varchar(32) NOT NULL,
  `path` text,
  `version` varchar(16) NOT NULL,
  `storage_name` varchar(32) NOT NULL,
  `zip_size` bigint(20) DEFAULT NULL,
  `mets_size` bigint(20) DEFAULT NULL,
  `saved_md5sum` char(32) DEFAULT NULL,
  `lastchecked` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastmd5check` timestamp NULL DEFAULT NULL,
  `restore_request` timestamp NULL DEFAULT NULL,
  `md5check_ok` tinyint(1) DEFAULT NULL,
  `deleted` tinyint(1) DEFAULT NULL,
  KEY `feed_backups_objid` (`namespace`,`id`),
  KEY `feed_backups_version` (`version`)
);

CREATE TABLE IF NOT EXISTS `feed_storage` (
  `namespace` varchar(10) NOT NULL,
  `id` varchar(32) NOT NULL,
  `storage_name` varchar(32) NOT NULL,
  `zip_size` bigint(20) DEFAULT NULL,
  `mets_size` bigint(20) DEFAULT NULL,
  `saved_md5sum` char(32) DEFAULT NULL,
  `deposit_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastchecked` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastmd5check` timestamp NULL DEFAULT NULL,
  `md5check_ok` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`namespace`, `id`, `storage_name`)
);

CREATE TABLE IF NOT EXISTS `feed_audit_detail` (
  `namespace` varchar(10) NOT NULL,
  `id` varchar(30) NOT NULL,
  `path` varchar(255) DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `detail` tinytext,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY `fs_log_status_objid_idx` (`namespace`,`id`)
);
USE `ht`;

CREATE TABLE IF NOT EXISTS `emma_items` (
  `remediated_item_id` varchar(255) PRIMARY KEY NOT NULL,
  `original_item_id` varchar(255) NOT NULL,
  `dc_format` varchar(255),
  `rem_coverage` text,
  `rem_remediation` text,
  `indexed_date` datetime
);
CREATE DATABASE IF NOT EXISTS `handle`;

CREATE TABLE IF NOT EXISTS `handle`.`handles` (
  `handle` varchar(255) NOT NULL DEFAULT '',
  `idx` int(11) NOT NULL DEFAULT '0',
  `type` blob,
  `data` blob,
  `ttl_type` smallint(6) DEFAULT NULL,
  `ttl` int(11) DEFAULT NULL,
  `timestamp` int(11) DEFAULT NULL,
  `refs` blob,
  `admin_read` tinyint(1) DEFAULT NULL,
  `admin_write` tinyint(1) DEFAULT NULL,
  `pub_read` tinyint(1) DEFAULT NULL,
  `pub_write` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`handle`,`idx`)
);

GRANT USAGE ON *.* TO 'feed'@'%' IDENTIFIED BY 'feed';
GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `ht`.* TO 'feed'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `handle`.* TO 'feed'@'%';
