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
