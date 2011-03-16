#!/usr/bin/perl

use warnings;
use strict;

use FindBin;

use Test::Harness;

chdir $FindBin::Bin;

#tests to run here
runtests qw{};
#runtests qw{remediate_yale.t validate_yale.t} 
