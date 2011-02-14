use warnings;
use strict;

use FindBin;

use Test::Harness;

chdir $FindBin::Bin;

runtests qw{ db.t objid.t classtests.t validate.t };
