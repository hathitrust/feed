#!/bin/bash
HTFEEDROOT=/htapps/babel/feed
export HTFEED_CONFIG=$HTFEEDROOT/etc/config.yaml
export PERL5LIB=$HTFEEDROOT/lib
for dir in `seq $1 5 24`; 
    do perl -w fsCrawl.pl "/sdr$dir" 2>&1 > $HTFEEDROOT/var/audit/sdr$dir.log &
done
