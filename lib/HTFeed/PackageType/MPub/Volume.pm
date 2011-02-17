#!/usr/bin/perl
package HTFeed::PackageType::MPub::Volume;

use warnings;
use strict;

use base qw(HTFeed::Volume);

sub get_download_location {
    # don't try to remove anything on clean
    return undef;
}

sub checksums {
	#verify checksums
}

1;

__END__
