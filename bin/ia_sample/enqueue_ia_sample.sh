#!/bin/bash

mysql -h mariadb -u feed --password=feed << EOT
  USE ht;
  LOAD DATA LOCAL INFILE '/usr/local/feed/bin/ia_sample/ia_sample.txt' REPLACE INTO TABLE feed_ia_arkid (ia_id, namespace, arkid);
  REPLACE INTO feed_zephir_items (namespace, id, collection, digitization_source, returned) (SELECT namespace, arkid, 'TEST','ia',0 from feed_ia_arkid);
EOT

cut -f 2,3 /usr/local/feed/bin/ia_sample/ia_sample.txt | perl -w /usr/local/feed/bin/enqueue.pl -p ia
