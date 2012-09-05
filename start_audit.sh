#!/bin/bash
HTFEEDROOT=/htapps/babel/feed
TODAY=`date +"%Y%m%d"`
export PERL5LIB=$HTFEEDROOT/lib
export LD_LIBRARY_PATH=$HTFEEDROOT/xerces-c-3.1.0/lib:$LD_LIBRARY_PATH
ORIGDIR=$1
shift
for dir in `seq $ORIGDIR 2 24`; 
    do perl -w $HTFEEDROOT/bin/audit/fsCrawl.pl $@ "/sdr$dir/obj" 2>&1 > $HTFEEDROOT/var/audit/sdr$dir-$TODAY.log &
done
