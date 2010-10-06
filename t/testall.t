#! /usr/bin/perl

use warnings;
use strict;
use lib qw(lib t/lib)

# load all the test classes I want to run
use HTFeed_Test::Stage::Download;

# and run them all
Test::Class->runtests;