#!/usr/bin/perl

use warnings;
use strict;

use HTFeed::Volume;
use HTFeed::Log;
use Getopt::Long;

HTFeed::Log->init();

# autoflush STDOUT
$| = 1;

my ($ignore_errors, $no_delete);

GetOptions ( "i" => \$ignore_errors, "n" => \$no_delete);

# read args
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;

unless ($objid and $namespace and $packagetype){
    print "usage: [-i] [-n] ingest_test.pl packagetype namespace objid\n";
    exit 0;
}

print sprintf("Test ingest of %s %s %s commencing...\n",$packagetype,$namespace,$objid);

# make Volume object
print 'Instantiating Volume object...';
my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);
print "success\n";

my $stage;
my $errors = 0;
foreach my $stage_name ( @{$volume->get_nspkg()->get('stages_to_run')} ){
    my $stage = eval "$stage_name->new(volume => \$volume)";
    $errors += run_stage($stage);
    if ($errors and !$ignore_errors){
        print "Ingest terminated due to failure\n";
        last;
    }
}

sub run_stage{
    my $stage = shift;
    
    print 'Running stage ' . ref($stage) ."..\n";
    
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
