#!/bin/bash

cover=/l/local/bin/cover

BASEDIR=/htapps/feed.babel
TESTDIR=$BASEDIR/feed/t

TEST=test_all.t

cd $TESTDIR

OUTPUT=$BASEDIR/test_results/web/logs/output

perl $cover -delete
HARNESS_PERL_SWITCHES=-MDevel::Cover perl $TEST >$OUTPUT 2>&1
perl $cover

WEB=$BASEDIR/test_results/web/output

#remove old coverage report
if [ -d $WEB ]; then
	rm -r $WEB
fi

#replace with new coverage report
mv cover_db $WEB

#adjust settings for web
chmod 755 $WEB
