#!/usr/bin/perl

use warnings;
use strict;
use lib qw{lib};
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(set_config);
set_config('1','debug');
use HTFeed::Test::Support qw(load_db_fixtures);

# get test classes
my $test_classes = HTFeed::Test::Support::get_test_classes();

load_db_fixtures;

# run the tests
Test::Class->runtests( @$test_classes );
