package HTFeed::Stage::Unpack;

use warnings;
use strict;

use base qw(HTFeed::Stage);

sub stage_info{
    return {success_state => 'unpacked', failure_state => 'ready'};
}

1;

__END__
