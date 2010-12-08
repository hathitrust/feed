package HTFeed::Stage::Unpack;

use warnings;
use strict;

sub stage_info{
    return {success_state => 'unpacked', failure_state => 'ready', failure_limit => 5};
}

1;

__END__
