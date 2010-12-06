#!/usr/bin/perl

use warnings;
use strict;

use HTFeed::Volume;
use HTFeed::Log;

HTFeed::Log->init();

# autoflush STDOUT
$| = 1;


# read args
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;

unless ($objid and $namespace and $packagetype){
    print "usage: ingest_test.pl packagetype namespace objid\n";
    exit 0;
}

print sprintf("Test ingest of %s %s %s commencing...\n",$packagetype,$namespace,$objid);

my $stage;
my $errors = 0;
my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);
foreach my $stage_name ( @{$volume->get_nspkg()->get('stages_to_run')} ){
    my $stage_volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);
    my $stage = eval "$stage_name->new(volume => \$stage_volume)";
    $errors += run_stage($stage);
}

sub run_stage{
    my $stage = shift;
    
    my $stagename = ref($stage);
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
