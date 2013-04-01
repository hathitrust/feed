#!/usr/bin/env perl

# config test
# test_config.pl <configfile | setname> [--dump-unfiltered-id-list filename] [--dump-id-list filename]

# prints id list to dumpfile, also prints stats on hypothetical config

use warnings;
use strict;
use v5.10.1;
use HTFeed::Dataset::Subset;
use HTFeed::Dataset::VolumeGroupMaker;

my $set_config_file;
my ($wanted_dump,$getting_dump);
my $help;
GetOptions(
    'dump-unfiltered-id-list=s' => \$wanted_dump,
    'dump-id-list=s'            => \$getting_dump,
    'help|?'                    => \$help,
) or pod2usage(2);
pod2usage(1) if $help;

if (scalar @ARGV == 1) {
    ($set_config_file) = @ARGV;
} else {
    pod2usage(2);
}

my $config;
if (-f $config_file) {
    $config = HTFeed::AppConfigFork->new(file => $config_file);
} else {
    $config = HTFeed::Dataset::Subset::get_subset_config($config);
}

my $wanted = HTFeed::Dataset::VolumeGroupMaker::get_volumes(%{$config});
say 'Volumes matched by config: '.$wanted->size();
my $allowed = HTFeed::Dataset::Tracking::get_all();
my $getting = $allowed->intersection($wanted);
say 'Volumes after rights filter: ' $getting->size();

# dump id lists
if ($wanted_dump) {
    $wanted->write_id_file($wanted_dump);
}

if ($getting_dump) {
    $getting->write_id_file($getting_dump);
}
