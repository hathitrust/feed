#!/bin/bash
SDRROOT=/htapps/babel
FEED_HOME=$SDRROOT/feed
TODAY=`date +"%Y%m%d"`
export PERL5LIB=$FEED_HOME/lib
export LD_LIBRARY_PATH=$FEED_HOME/xerces-c-3.1.0/lib:$LD_LIBRARY_PATH
ORIGDIR=$1
shift
for dir in `seq $ORIGDIR 2 24`; 
    do perl -w $SDRROOT/audit/fsCrawl.pl $@ "/sdr$dir/obj" 2>&1 > $SDRROOT/audit/log/sdr$dir-$TODAY.log &
done
