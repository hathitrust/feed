#!/usr/bin/perl

use warnings;
use strict;
use lib qw{lib};
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(set_config get_config);
set_config('1','debug');
use HTFeed::Test::Support qw(load_db_fixtures);

# get test classes
my $test_classes = HTFeed::Test::Support::get_test_classes();

load_db_fixtures;

my $undamaged = get_config('test_staging','undamaged');
my $damaged = get_config('test_staging','damaged');

symlink("$FindBin::Bin/fixtures/UNDAMAGED",$undamaged) if( ! -e $undamaged);
symlink("$FindBin::Bin/fixtures/DAMAGED",$damaged) if( ! -e $damaged);

# run the tests
Test::Class->runtests( @$test_classes );
