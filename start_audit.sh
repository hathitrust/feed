#!/bin/bash
HTFEEDROOT=/htapps/babel/feed
TODAY=`date +"%Y%m%d"`
export HTFEED_CONFIG=$HTFEEDROOT/etc/config.yaml
export PERL5LIB=$HTFEEDROOT/lib
export LD_LIBRARY_PATH=$HTFEEDROOT/xerces-c-3.1.0/lib:$LD_LIBRARY_PATH
for dir in `seq $1 2 24`; 
    do perl -w $HTFEEDROOT/bin/audit/fsCrawl.pl $@ "/sdr$dir/obj" 2>&1 > $HTFEEDROOT/var/audit/sdr$dir-$TODAY.log &
done
