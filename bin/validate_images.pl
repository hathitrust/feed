#!/usr/bin/perl

=description
validate_images.pl validates all jhove-validatable files in a directory
=cut

use strict;
use warnings;
use HTFeed::TestVolume;
use HTFeed::VolumeValidator;
use HTFeed::Log;

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
my $dir = shift;
my $objid = shift;
unless ($packagetype and $namespace and $dir){
    print "usage: validate_images.pl packagetype namespace dir [objid]\n";
    exit 0;
}

# run validation
my $volume;
$volume = HTFeed::TestVolume->new(namespace => $namespace,packagetype => $packagetype,dir=>$dir,objid=>$objid) if (defined $objid);
$volume = HTFeed::TestVolume->new(namespace => $namespace,packagetype => $packagetype,dir=>$dir) if (! defined $objid);

my $vol_val = HTFeed::VolumeValidator->new(volume => $volume);

# abuse encapsulation and change internal structure of $vol_val object
$vol_val->{run_stages} = [qw(validate_metadata)];

$vol_val->run();

if ($vol_val->succeeded()){
    print "success!\n";
}
else {print "failure!\n";}
