#!/usr/bin/perl

use warnings;
use strict;
use lib qw{lib};

use HTFeed::Log {root_logger => 'INFO, screen'};

# load all test classes
#use HTFeed::Test::Support qw(get_test_classes);
use HTFeed::Test::Support;

# run all tests
my $test_classes = HTFeed::Test::Support::get_test_classes();
Test::Class->runtests( @$test_classes );
