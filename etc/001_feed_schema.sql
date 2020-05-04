BEGIN TRANSACTION;
ATTACH '/tmp/rights.db' AS ht_rights;
CREATE TABLE "feed_log" (
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
  `stage` varchar(255) DEFAULT NULL
);
CREATE TABLE "feed_premis_events" (
  `namespace` varchar(8) NOT NULL DEFAULT '',
  `id` varchar(32) NOT NULL DEFAULT '',
  `eventtype_id` varchar(64) NOT NULL DEFAULT '',
  `date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `outcome` text,
  `eventid` char(36) DEFAULT NULL,
  `custom_xml` text,
  PRIMARY KEY (`namespace`,`id`,`eventtype_id`)
);
CREATE TABLE `feed_queue` (
  `pkg_type` varchar(32) DEFAULT NULL,
  `namespace` varchar(8) NOT NULL DEFAULT '',
  `id` varchar(32) NOT NULL DEFAULT '',
  `status` varchar(20) NOT NULL DEFAULT 'ready',
  `reset_status` varchar(20) DEFAULT NULL,
  `update_stamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `node` varchar(255) DEFAULT NULL,
  `failure_count` int(11) NOT NULL DEFAULT '0',
  `priority` int(11) DEFAULT NULL,
  PRIMARY KEY (`namespace`,`id`));
CREATE TABLE `feed_ia_arkid` (
  `ia_id` varchar(255) PRIMARY KEY,
  `namespace` varchar(32),
  `arkid` varchar(32), resolution varchar(8));
CREATE TABLE `feed_zephir_items` (
  `namespace` varchar(5) NOT NULL,
  `id` varchar(32) NOT NULL,
  `collection` varchar(32) NOT NULL,
  `digitization_source` varchar(32) NOT NULL,
  `returned` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`namespace`,`id`)
);
CREATE TABLE `feed_blacklist` (
	`namespace` varchar(8) NOT NULL DEFAULT '',
	`id` varchar(32) NOT NULL DEFAULT '',
	`note` text,
	`time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (`namespace`,`id`)
);
CREATE TABLE `feed_priority` (
  `priority` tinyint(3) DEFAULT '254',
  `pkg_type` varchar(32) DEFAULT NULL,
  `namespace` varchar(8) DEFAULT NULL
);
CREATE TABLE `ht_collections` (
  `collection` varchar(16) NOT NULL,
  `content_provider_cluster` varchar(255) DEFAULT NULL,
  `responsible_entity` varchar(64) DEFAULT NULL,
  `original_from_inst_id` varchar(32) DEFAULT NULL,
  `billing_entity` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`collection`)
);
CREATE TABLE `ht_collection_digitizers` (
  `collection` varchar(16) DEFAULT NULL,
  `digitization_source` varchar(16) DEFAULT NULL,
  `access_profile` tinyint(4) DEFAULT NULL
);
CREATE TABLE ht_rights.sources (
  `id` tinyint(3) NOT NULL,
  `name` varchar(16) NOT NULL DEFAULT '',
  `dscr` text NOT NULL,
  `access_profile` tinyint(3) DEFAULT NULL,
  `digitization_source` varchar(64) DEFAULT NULL
);
COMMIT;
