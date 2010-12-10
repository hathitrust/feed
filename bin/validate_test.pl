#!/usr/bin/perl

use strict;
use warnings;
use HTFeed::Volume;
use HTFeed::VolumeValidator;
use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(set_config);

# read args
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;
my $dir = shift;

unless ($objid and $namespace and $packagetype){
    print "usage: validate_test.pl packagetype namespace objid [staging dir]\n";
    exit 0;
}

set_config($dir,'staging'=>'memory') if (defined $dir);

# run validation
my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);

my $vol_val = HTFeed::VolumeValidator->new(volume => $volume);

$vol_val->run();

if ($vol_val->succeeded()){
    print "success!\n";
}
else {print "failure!\n";}
