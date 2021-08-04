REPLACE INTO feed_ia_arkid VALUES('test_ia_id','test','ark:/13960/t00000431',NULL);
REPLACE INTO feed_zephir_items VALUES('test','39015002008244','TEST','test',0);
REPLACE INTO feed_zephir_items VALUES('test','35112102255835','TEST','test',0);
REPLACE INTO feed_zephir_items VALUES('test','ark:/13960/t00000431','TEST','ia',0);
REPLACE INTO feed_queue_disallow VALUES('test','39015002008244','disallow test item',CURRENT_TIMESTAMP);
REPLACE INTO ht_collections VALUES ('TEST','test','test','test','test');
REPLACE INTO ht_collection_digitizers VALUES ('TEST','test','1');
REPLACE INTO ht_collection_digitizers VALUES ('TEST','ia','1');
