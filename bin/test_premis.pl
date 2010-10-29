#!/usr/bin/perl

use HTFeed::Volume;
use HTFeed::METS;
use DBI;
use HTFeed::Log;

# for testing until we get the test harness going, then delete this line
use HTFeed::Test::Support;

HTFeed::Log->init();

my $volume = new HTFeed::Volume(objid => '39002001151019',
    namespace => 'yale',
    packagetype => 'yale');

my $mets = new HTFeed::METS(volume => $volume);

$mets->_add_premis();
