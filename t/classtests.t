#!/usr/bin/perl

use warnings;
use strict;
use lib qw{lib};
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(get_config set_config);
set_config('1','debug');
use HTFeed::Test::Support;

# get test classes
my $test_classes = HTFeed::Test::Support::get_test_classes();

# run the tests
Test::Class->runtests( @$test_classes );
