#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(set_config);
use HTFeed::TestVolume;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use HTFeed::Stage::Done;
use strict;
use warnings;

# autoflush STDOUT
$| = 1;

# report all image errors
set_config(0,'stop_on_error');

my $clean = 1;

my $packagetype = "vendoraudio";
my $namespace = "mdp";

my $objid = shift;
my $dir = shift;
unless( $dir ){
    die 'Must specify directory to validate';
}

my $volume =  HTFeed::TestVolume->new(packagetype => $packagetype, namespace => $namespace, dir => $dir, objid => $objid);

my $vol_val = HTFeed::PackageType::Audio::VolumeValidator->new(volume => $volume);
@{$vol_val->{run_stages}} = grep { $_ ne 'validate_digitizer' } @{$vol_val->{run_stages}};

$vol_val->run();

if($vol_val->succeeded()) {
  exit 0;
} else {
  exit 1;
}

1;
