#!/usr/bin/perl

use warnings;
use strict;

use HTFeed::Volume;
use HTFeed::Log {root_logger => 'INFO, screen'};
use Getopt::Long;

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

my $stage;
my $errors = 0;
my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);
foreach my $stage_name ( @{$volume->get_stages()} ){
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
    
    print "Running stage $stagename..\n";
    
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
