#!/usr/bin/perl

# Randomly chooses a Data Den object to validate against METS and DB.
# This script should be run hourly, give or take.

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::DataDenZipAudit;
use HTFeed::Log {root_logger => 'INFO, screen'};

my $volume = HTFeed::DataDenZipAudit::choose();
my $audit = HTFeed::DataDenZipAudit->new(namespace => $volume->{namespace},
                                         objid => $volume->{objid},
                                         path => $volume->{path},
                                         version => $volume->{version});
$audit->run();
