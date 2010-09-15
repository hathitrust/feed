#!/usr/bin/perl

use strict;
use warnings;
use HTFeed::Volume;
use HTFeed::VolumeValidator;
use Log::Log4perl;

my $l4p_config = "/htapps/rrotter.babel/git/feed/etc/test_config.l4p";
Log::Log4perl->init($l4p_config);

Log::Log4perl->get_logger("")->trace("xpathsuite has initialized l4p!");


my $volume = HTFeed::Volume->new(objid => "b806977",namespace => "uc1",packagetype => "google");
#my $volume = HTFeed::Volume->new(objid => "UOM-39015032210646",namespace => "mdp",packagetype => "google");
#my $volume = HTFeed::Volume->new(objid => "39015032210646",namespace => "mdp",packagetype => "google");


my $vol_val = HTFeed::VolumeValidator->new(volume => $volume);

$vol_val->run();

if ($vol_val->succeeded()){
    print "success!";
}
else {print "failure!";}

print "ok ";