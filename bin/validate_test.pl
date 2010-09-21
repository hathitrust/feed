#!/usr/bin/perl

use strict;
use warnings;
use HTFeed::Volume;
use HTFeed::VolumeValidator;
use Log::Log4perl;

# check for legacy environment vars
unless (defined $ENV{GROOVE_WORKING_DIRECTORY} and defined $ENV{GROOVE_CONFIG}){
    print "GROOVE_WORKING_DIRECTORY and GROOVE_CONFIG must be set\n";
    exit 0;
}

# check for / read environment vars
my $l4p_config;
if (defined $ENV{HTFEED_L4P}){
    $l4p_config = $ENV{HTFEED_L4P};
}
else{
    print "set HTFEED_L4P\n";
    exit 0;
}

Log::Log4perl->init($l4p_config);

Log::Log4perl->get_logger("")->trace("validate_test has initialized l4p!");

# read args
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;

unless ($objid and $namespace and $packagetype){
    print "useage: vt packagetype namespace objid\n";
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
