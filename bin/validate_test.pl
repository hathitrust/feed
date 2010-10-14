#!/usr/bin/perl

use strict;
use warnings;
use HTFeed::Volume;
use HTFeed::VolumeValidator;
use HTFeed::Log;

# for testing until we get the test harness going, then delete this line
use HTFeed::Test::Support;

HTFeed::Log->init();

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

# run validation
my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);

my $vol_val = HTFeed::VolumeValidator->new(volume => $volume);

$vol_val->run();

if ($vol_val->succeeded()){
    print "success!\n";
}
else {print "failure!\n";}
