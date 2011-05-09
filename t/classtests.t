#!/usr/bin/perl

use warnings;
use strict;
use lib qw{lib};

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";

use HTFeed::Log {root_logger => 'INFO, file'};
use HTFeed::Config qw(get_config set_config);
set_config('1','debug');

# load all test classes
#use HTFeed::Test::Support qw(get_test_classes);
use HTFeed::Test::Support;

# run all tests
my $test_classes = HTFeed::Test::Support::get_test_classes();
Test::Class->runtests( @$test_classes );
