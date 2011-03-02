#!/usr/bin/perl
package HTFeed::PackageType::Audio::Volume;

use warnings;
use strict;
use HTFeed::Volume;
use base qw(HTFeed::Volume);
use Log::Log4perl qw(get_logger);

my $logger = get_logger(__PACKAGE__);

sub get_download_location {
    # don't try to remove anything on clean
    return undef;

}

1;
