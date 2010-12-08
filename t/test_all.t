use warnings;
use strict;

use FindBin;

use Test::Harness;

chdir $FindBin::Bin;
runtests qw{ objid.t validate.t };

