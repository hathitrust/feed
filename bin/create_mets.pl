#!/usr/bin/perl -w

use strict;
use Carp;
use HTFeed::Volume;
use HTFeed::METS;
use DBI;

use HTFeed::Log;

# for testing until we get the test harness going, then delete this line
use HTFeed::Test::Support;

HTFeed::Log->init();

my $ns = $ARGV[0];
my $objid = $ARGV[1];
my $grinid = $ARGV[2];
my $packagetype = $ARGV[3];

$config->set('packagetype', $packagetype);



my $volume = HTFeed::Volume->new(objid => $objid, namespace => $ns, packagetype => $packagetype);
my $mets_stage = HTFeed::METS->new(volume => $volume);
print "Creating METS..\n";
$mets_stage->run_stage();
			
