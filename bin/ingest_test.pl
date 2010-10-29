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
use HTFeed::Stage::Sample;
use HTFeed::Stage::Collate;

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

my $stage;

# Download
print 'Downloading...';
$stage = HTFeed::PackageType::Google::Download->new(volume => $volume);
#$stage = HTFeed::PackageType::IA::Download->new(volume => $volume);
run_stage( $stage );

#=skip
# Unpack
print 'Unpacking...';
$stage = HTFeed::PackageType::Google::Unpack->new(volume => $volume);
run_stage( $stage );

# Validation
print 'Validating...';
$stage = HTFeed::VolumeValidator->new(volume => $volume);
run_stage( $stage );

# Pack
print 'Packing...';
$stage = HTFeed::Stage::Pack->new(volume => $volume);
run_stage( $stage );

# Mets
print "Metsing...not implimented\n";

# Sample
print 'Sampling...';
$stage = HTFeed::Stage::Sample->new(volume => $volume);
run_stage( $stage );

# Collate
print 'Collating...';
$stage = HTFeed::Stage::Collate->new(volume => $volume);
run_stage( $stage );
#=cut
sub run_stage{
    my $stage = shift;
    $stage->run();
    if ($stage->succeeded()){
        print "success\n";
    }
    else{
        print "failure\n";
    }
}
