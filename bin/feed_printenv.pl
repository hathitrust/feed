#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed;
use HTFeed::Config qw(get_config);

HTFeed::Config::_dump();

1;
