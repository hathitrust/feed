#!/usr/bin/perl

use warnings;
use strict;
use lib qw{lib};

use HTFeed::Log {root_logger => 'INFO, screen'};

# define list of test classes
## TODO: replace this with a list of all files called Test.pm (since AbstractTest.pm convention makes this safe)
use constant TEST_CLASSES => [qw(
    HTFeed::Namespace::Test
    HTFeed::PackageType::Test
    HTFeed::Stage::Collate::Test
    HTFeed::Stage::Download::Test
    HTFeed::Stage::Handle::Test
    HTFeed::Stage::Pack::Test
    HTFeed::Stage::Sample::Test
    HTFeed::Stage::Unpack::Test
    )];
    
# requre all test classes
BEGIN{
    my $test_classes = TEST_CLASSES;
    foreach my $class ( @$test_classes ){
        eval "require $class";
    }
}

# run all tests
my $test_classes = TEST_CLASSES;
Test::Class->runtests( @$test_classes );