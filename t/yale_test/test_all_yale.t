#!/usr/bin/perl

use warnings;
use strict;

use FindBin;

use Test::Harness;

chdir $FindBin::Bin;

runtests qw{remediate_yale.t validate_yale.t};
