#!/usr/bin/perl

use warnings;
use strict;

use HTFeed::Test::Support qw(md5_dir);

print md5_dir(shift) . qq(\n);
