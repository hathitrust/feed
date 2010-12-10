#!/usr/bin/perl

use warnings;
use strict;
use lib qw{lib};

use HTFeed::Log {root_logger => 'INFO, screen'};

# define list of test classes
use constant TEST_CLASSES => [qw(
    HTFeed::Stage::Download::Test
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
foreach my $class ( @$test_classes ){
    eval "$class->new->runtests";
}
