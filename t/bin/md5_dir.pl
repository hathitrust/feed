#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";

use HTFeed::Test::Support qw(md5_dir);

print md5_dir(shift) . qq(\n);
