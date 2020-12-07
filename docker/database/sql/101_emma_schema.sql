USE `ht`;

CREATE TABLE IF NOT EXISTS `emma_items` (
  `remediated_item_id` varchar(255) PRIMARY KEY NOT NULL,
  `original_item_id` varchar(255) NOT NULL,
  `dc_format` varchar(255),
  `rem_coverage` text,
  `rem_remediation` text
);
