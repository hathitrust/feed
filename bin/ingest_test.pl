#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Volume;
use HTFeed::Log {root_logger => 'TRACE, screen'};
use Getopt::Long;
use HTFeed::StagingSetup;

# autoflush STDOUT
$| = 1;

my ($ignore_errors, $no_delete);

GetOptions ( "i" => \$ignore_errors, "n" => \$no_delete);

# read args
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;
my $startstate  = shift;

unless ($objid and $namespace and $packagetype){
    print "usage: [-i] [-n] ingest_test.pl packagetype namespace objid [ state ]\n";
    exit 0;
}

HTFeed::StagingSetup::make_stage();

my $stage;
my $errors = 0;
my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);

my $stagelist = $volume->get_stages($startstate);
print sprintf("Test ingest of %s %s %s commencing...\n",$packagetype,$namespace,$objid);
print "Running stages: \n\n" . join("\n",@$stagelist), "\n";
print "-----\n";
foreach my $stage_name (@$stagelist) {
    my $stage_volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);
    my $stage = eval "$stage_name->new(volume => \$stage_volume)";
    $errors += run_stage($stage);
    if ($errors and !$ignore_errors){
        print "Ingest terminated due to failure\n";
        last;
    }
}

sub run_stage{
    my $stage = shift;
    
    print "Running stage " . ref($stage) . "..\n";
    
    $stage->run();
    if ($stage->succeeded()){
        print "success\n";
    }
    else{
        print "failure\n";
    }
    
    return $stage->failed();
}

print 'Volume ' . $volume->get_identifier() . " ingested unsuccessfully with $errors errors!\n" if ($errors);
print 'Volume ' . $volume->get_identifier() . " ingested successfully!\n" unless ($errors);

