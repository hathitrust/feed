#!/usr/bin/perl

use warnings;
use strict;

use HTFeed::Volume;
use HTFeed::VolumeValidator;
use HTFeed::Log;

use HTFeed::PackageType::Google::Download;
use HTFeed::PackageType::IA::Download;
use HTFeed::PackageType::Google::Unpack;
use HTFeed::Stage::Pack;
use HTFeed::METS;
use HTFeed::Stage::Sample;
use HTFeed::Stage::Collate;
use HTFeed::Stage::Handle;

HTFeed::Log->init();

# autoflush STDOUT
$| = 1;

# check for legacy environment vars
unless (defined $ENV{GROOVE_WORKING_DIRECTORY} and defined $ENV{GROOVE_CONFIG}){
    print "GROOVE_WORKING_DIRECTORY and GROOVE_CONFIG must be set\n";
    exit 0;
}

# read args
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;

unless ($objid and $namespace and $packagetype){
    print "usage: vt packagetype namespace objid\n";
    exit 0;
}

print sprintf("Test ingest of %s %s %s commencing...\n",$packagetype,$namespace,$objid);

# make Volume object
print 'Instantiating Volume object...';
my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);
print "success\n";

print join qq{\n}, @{$volume->get_nspkg()->get('stages_to_run')};

my $stage;
my $errors = 0;
foreach my $stage_name ( @{$volume->get_nspkg()->get('stages_to_run')} ){
    my $stage = eval "$stage_name->new(volume => \$volume)";
    $errors += run_stage($stage);
}

sub run_stage{
    my $stage = shift;
    
    ref($stage) =~ /^.*::(\w*)/;
    my $verb = $1;
    chop $verb if ($verb =~ /e$/);
    print $verb . 'ing...';
    
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
