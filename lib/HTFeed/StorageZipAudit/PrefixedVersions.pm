#!/usr/bin/perl
package HTFeed::StorageZipAudit::PrefixedVersions;

use strict;
use warnings;
use Carp;
use Log::Log4perl;

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

use base qw(HTFeed::StorageZipAudit);

1;

__END__
