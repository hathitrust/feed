use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTFeed::Log { root_logger => 'INFO, dbi, screen' };
use HTFeed::Version;
use HTFeed::QueueRunner;

HTFeed::QueueRunner->new()->run();


