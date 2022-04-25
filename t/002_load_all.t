use strict;
use warnings;

use Test::More tests => 2;
BEGIN { use_ok ('HTFeed::Version'); }

ok(HTFeed::Version::_long_version);
