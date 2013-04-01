#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed;
use HTFeed::Config qw(get_config);

unless (scalar @ARGV) {
    HTFeed::Config::_dump();
    exit 0;
}

my $value = get_config($ARGV[0]);
print "$value\n";

1;
