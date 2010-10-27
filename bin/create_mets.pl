#!/usr/bin/perl -w

use strict;
use Carp;
use GROOVE::Book;
use GROOVE::DBTools;
use GROOVE::Mets;
use GROOVE::Zip;
use GROOVE::Config;
use HTFeed::Volume;
use HTFeed::METS;
use DBI;

use HTFeed::Log;

# for testing until we get the test harness going, then delete this line
use HTFeed::Test::Support;

HTFeed::Log->init();

# check for legacy environment vars
unless (defined $ENV{GROOVE_WORKING_DIRECTORY} and defined $ENV{GROOVE_CONFIG}){
    print "GROOVE_WORKING_DIRECTORY and GROOVE_CONFIG must be set\n";
    exit 0;
}
my $db = new GROOVE::DBTools();

if(! defined $db) {
    die("Could not create DBTools object");
}

my $config = new GROOVE::Config();

my $ns = $ARGV[0];
my $objid = $ARGV[1];
my $grinid = $ARGV[2];
my $packagetype = $ARGV[3];

$config->set('packagetype', $packagetype);


#my $book = new GROOVE::Book($objid, $ns, $path, $packagetype);
my $book = new GROOVE::Book($objid, $ns, $packagetype);

if(! defined $book) {
    die("GROOVE::Book object not defined");
}

if(defined $grinid && $grinid ne 'null') {
	$book->set_grinid($grinid);
}


my $path = "$ENV{GROOVE_WORKING_DIRECTORY}/$objid";

print "Creating zip file..\n";
if(! -e "$path/$objid.zip") {
    my $zip = new GROOVE::Zip($book, $config);

	if(! defined $zip) {
		die("GROOVE::Zip object not defined");
	}

	eval {
		if(! $zip->zip()) {
			die("zip unsuccessful: " . $zip->get_errors());
		}
		else {
			print "Zip file created successfully\n";
		}
	};
	if($@) {
		print "Error zipping: $@\n";

		exit();
	}
}
else {
	print "$path/$objid.zip already exists\n";
}


my $volume = HTFeed::Volume->new(objid => $objid, namespace => $ns, packagetype => $packagetype);
my $mets_stage = HTFeed::METS->new(volume => $volume);
print "Creating METS..\n";
$mets_stage->run_stage();
			
