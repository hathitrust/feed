CREATE DATABASE IF NOT EXISTS ht_rights;
USE ht_rights;

DROP TABLE IF EXISTS `access_profiles`;
CREATE TABLE `access_profiles` (
  `id` tinyint(3) unsigned NOT NULL,
  `name` varchar(16) NOT NULL,
  `dscr` text NOT NULL,
  PRIMARY KEY (`id`)
);

LOCK TABLES `access_profiles` WRITE;
INSERT INTO `access_profiles` VALUES (1,'open','Unrestricted image and full-volume download (e.g. Internet Archive)'),(2,'google','Restricted public full-volume download - watermarked PDF only, when logged in or with Data API key (e.g. Google)'),(3,'page','Page access only: no PDF or ZIP download for anyone (e.g. UM Press)'),(4,'page+lowres','Low resolution watermarked image derivatives only (e.g. MDL)');
UNLOCK TABLES;


DROP TABLE IF EXISTS `attributes`;
CREATE TABLE `attributes` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('access','copyright') NOT NULL DEFAULT 'access',
  `name` varchar(16) NOT NULL DEFAULT '',
  `dscr` text NOT NULL,
  UNIQUE KEY `id` (`id`)
) AUTO_INCREMENT=28;


LOCK TABLES `attributes` WRITE;
INSERT INTO `attributes` VALUES (1,'copyright','pd','public domain'),(2,'copyright','ic','in copyright'),(3,'copyright','op','out-of-print (implies in-copyright)'),(4,'copyright','orph','copyright-orphaned (implies in-copyright)'),(6,'access','umall','available to UM affiliates and walk-in patrons (all campuses)'),(7,'access','ic-world','in-copyright and permitted as world viewable by the copyright holder'),(5,'copyright','und','undetermined copyright status'),(8,'access','nobody','available to nobody; blocked for all users'),(9,'copyright','pdus','public domain only when viewed in the US'),(10,'copyright','cc-by-3.0','Creative Commons Attribution license, 3.0 Unported'),(11,'copyright','cc-by-nd-3.0','Creative Commons Attribution-NoDerivatives license, 3.0 Unported'),(12,'copyright','cc-by-nc-nd-3.0','Creative Commons Attribution-NonCommercial-NoDerivatives license, 3.0 Unported'),(13,'copyright','cc-by-nc-3.0','Creative Commons Attribution-NonCommercial license, 3.0 Unported'),(14,'copyright','cc-by-nc-sa-3.0','Creative Commons Attribution-NonCommercial-ShareAlike license, 3.0 Unported'),(15,'copyright','cc-by-sa-3.0','Creative Commons Attribution-ShareAlike license, 3.0 Unported'),(16,'copyright','orphcand','orphan candidate - in 90-day holding period (implies in-copyright)'),(17,'copyright','cc-zero','Creative Commons Zero license (implies pd)'),(18,'access','und-world','undetermined copyright status and permitted as world viewable by the depositor'),(19,'copyright','icus','in copyright in the US'),(20,'copyright','cc-by-4.0','Creative Commons Attribution 4.0 International license'),(21,'copyright','cc-by-nd-4.0','Creative Commons Attribution-NoDerivatives 4.0 International license'),(22,'copyright','cc-by-nc-nd-4.0','Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International license'),(23,'copyright','cc-by-nc-4.0','Creative Commons Attribution-NonCommercial 4.0 International license'),(24,'copyright','cc-by-nc-sa-4.0','Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International license'),(25,'copyright','cc-by-sa-4.0','Creative Commons Attribution-ShareAlike 4.0 International license'),(26,'access','pd-pvt','public domain but access limited due to privacy concerns'),(27,'access','supp','suppressed from view; see note for details');
UNLOCK TABLES;


DROP TABLE IF EXISTS `reasons`;
CREATE TABLE `reasons` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(16) NOT NULL DEFAULT '',
  `dscr` text NOT NULL,
  UNIQUE KEY `id` (`id`)
) AUTO_INCREMENT=19;


LOCK TABLES `reasons` WRITE;
INSERT INTO `reasons` VALUES (1,'bib','bibliographically-derived by automatic processes'),(2,'ncn','no printed copyright notice'),(3,'con','contractual agreement with copyright holder on file'),(4,'ddd','due diligence documentation on file'),(5,'man','manual access control override; see note for details'),(6,'pvt','private personal information visible'),(7,'ren','copyright renewal research was conducted'),(8,'nfi','needs further investigation (copyright research partially complete, and an ambiguous, unclear, or other time-consuming situation was encountered)'),(9,'cdpp','title page or verso contain copyright date and/or place of publication information not in bib record'),(10,'ipma','in-print and market availability research was conducted'),(11,'unp','unpublished work'),(12,'gfv','Google viewability set at VIEW_FULL'),(13,'crms','derived from multiple reviews in the Copyright Review Management System (CRMS) via an internal resolution policy; consult CRMS records for details'),(14,'add','author death date research was conducted or notification was received from authoritative source'),(15,'exp','expiration of copyright term for non-US work with corporate author'),(16,'del','deleted from the repository; see note for details'),(17,'gatt','non-US public domain work restored to in-copyright in the US by GATT'),(18,'supp','suppressed from view; see note for details');
UNLOCK TABLES;


DROP TABLE IF EXISTS `sources`;
CREATE TABLE `sources` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(16) NOT NULL DEFAULT '',
  `dscr` text NOT NULL,
  `access_profile` tinyint(3) unsigned DEFAULT NULL,
  `digitization_source` varchar(64) DEFAULT NULL,
  UNIQUE KEY `id` (`id`)
) AUTO_INCREMENT=59;


LOCK TABLES `sources` WRITE;
INSERT INTO `sources` VALUES (1,'google','Google',2,'google'),(2,'lit-dlps-dc','University of Michigan Library IT, Digital Library Production Service, Digital Conversion',1,'umich*;umdl-umich'),(3,'ump','University of Michigan Press',3,'umich;press-umich*'),(4,'ia','Internet Archive',1,'archive'),(5,'yale','Yale University (with support from Microsoft)',1,'yale;ht_support-microsoft*'),(6,'mdl','Minnesota Digital Library',4,'mndigital'),(7,'mhs','Minnesota Historical Society',4,'mnhs'),(8,'usup','Utah State University Press',3,'usupress'),(9,'ucm','Universidad Complutense de Madrid',1,'ucm'),(10,'purd','Purdue University',1,'purdue'),(11,'getty','Getty Research Institute',1,'getty'),(12,'um-dc-mp','University of Michigan, Duderstadt Center, Millennium Project',1,'umich;milproj-dc-umich*'),(13,'uiuc','University of Illinois at Urbana-Champaign',1,'illinois'),(14,'brooklynmuseum','Brooklyn Museum',1,'brooklynmuseum'),(15,'uf','State University System of Florida',1,'flbog'),(16,'tamu','Texas A&M',1,'tamu'),(17,'udel','University of Delaware',1,'udel'),(18,'private','Private Donor',1,'ht_private'),(19,'umich','University of Michigan (Other)',1,'umich'),(20,'clark','Clark Art Institute',1,'clarkart'),(21,'ku','Knowledge Unlatched',1,'knowledgeunlatched'),(22,'mcgill','McGill University',1,'mcgill'),(23,'bc','Boston College',1,'bc'),(24,'nnc','Columbia University',1,'columbia'),(25,'geu','Emory University',1,'emory'),(26,'borndigital','Born Digital (placeholder)',1,NULL),(27,'yale2','Yale University',1,'yale'),(28,'mou','University of Missouri',1,'missouri'),(29,'chtanc','National Central Library of Taiwan',1,'washington;ncl'),(30,'bentley-umich','Bentley Historical Library, University of Michigan',1,'umich*;bentley-umich'),(31,'clements-umich','William L. Clements Library, University of Michigan',1,'umich*;clements-umich'),(32,'wau','University of Washington',1,'washington'),(33,'cornell','Cornell University',1,'cornell'),(34,'cornell-ms','Cornell University (with support from Microsoft)',1,'cornell*;ht_support-microsoft'),(35,'umd','University of Maryland',1,'umd'),(36,'frick','The Frick Collection',1,'frick'),(37,'northwestern','Northwestern University',1,'northwestern'),(38,'umn','University of Minnesota',1,'umn'),(39,'berkeley','University of California, Berkeley',1,'berkeley'),(40,'ucmerced','University of California, Merced',1,'ucmerced'),(41,'nd','University of Notre Dame',1,'nd'),(42,'princeton','Princeton University',1,'princeton'),(43,'uq','The University of Queensland',1,'uq'),(44,'ucla','University of California, Los Angeles',1,'ucla'),(45,'osu','The Ohio State University',1,'osu'),(46,'upenn','University of Pennsylvania',1,'upenn'),(47,'aub','American University of Beirut',1,'aub'),(48,'ucsd','University of California San Diego',1,'ucsd'),(49,'harvard','Harvard University',1,'harvard'),(50,'miami','University of Miami',1,'miami'),(51,'vcu','Virginia Commonwealth University',1,'vcu'),(52,'jhu','Johns Hopkins University',1,'jhu'),(53,'haverford','Haverford College',1,'haverford'),(54,'asu','Arizona State University',1,'asu'),(55,'buffalo','University at Buffalo',1,'buffalo'),(56,'okstate','Oklahoma State University',1,'okstate'),(57,'txstate','Texas State University',1,'txstate'),(58,'temple','Temple University',1,'temple');
UNLOCK TABLES;

CREATE TABLE `rights_current` (
	  `namespace` varchar(8) NOT NULL,
	  `id` varchar(32) NOT NULL DEFAULT '',
	  `attr` tinyint(4) NOT NULL,
	  `reason` tinyint(4) NOT NULL,
	  `source` tinyint(4) NOT NULL,
	  `access_profile` tinyint(4) NOT NULL,
	  `user` varchar(32) NOT NULL DEFAULT '',
	  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	  `note` text,
	  PRIMARY KEY (`namespace`,`id`),
	  KEY `time` (`time`),
	  KEY `rights_current_attr_index` (`attr`)
);

GRANT SELECT ON `ht_rights`.* TO 'ht_repository'@'%' IDENTIFIED BY 'ht_repository';
