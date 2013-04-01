#!/usr/bin/perl

# basic tests to run to make sure packaged ingest tools
# are not totally brain-dead 

use warnings;
use strict;
use lib qw{lib};
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use HTFeed::Log {root_logger => 'INFO, file'};
use HTFeed::Config qw(get_config set_config);
set_config('1','debug');
use HTFeed::Test::Support;

# run the tests
Test::Class->runtests( qw(
    HTFeed::Namespace::Test
    HTFeed::PackageType::Test
    HTFeed::Stage::Collate::Test
    HTFeed::Stage::Download::Test
    HTFeed::Stage::Handle::Test
    HTFeed::Stage::Pack::Test
    HTFeed::Stage::Unpack::Test
));
