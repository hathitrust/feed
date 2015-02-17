#!/bin/bash
# send daily ingest summary

. $FEED_HOME/etc/mysqlparams

(echo "Items changing status yesterday: "
$MYSQL -e "select pkg_type, status, count(*) from feed_queue where update_stamp >= current_date() - 1 and update_stamp <= current_date() group by pkg_type, status;"
echo -n
echo "Error summary from yesterday: "
$MYSQL -e "select pkg_type, message, operation, field, count(*) from feed_queue natural join feed_last_error where update_stamp >= current_date() -1 and update_stamp <= current_date and status = 'punted' group by pkg_type, message, operation, field" ) | /bin/mailx -s "Daily HathiTrust ingest summary" -r libadm@umich.edu lit-cs-ingest@umich.edu
