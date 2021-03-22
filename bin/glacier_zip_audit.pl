#!/usr/bin/perl

# Randomly chooses a Glacier Deep Storage object object to validate
# and issues a restore request for it.
# Checks other objects for which restores have been issued and runs validation
# for any that are ready.
# This script should be run daily, give or take.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::GlacierZipAudit;
use HTFeed::Log {root_logger => 'INFO, screen'};

my $volume = HTFeed::GlacierZipAudit::choose();
my $audit = HTFeed::GlacierZipAudit->new(namespace => $volume->{namespace},
                                         objid => $volume->{objid},
                                         path => $volume->{path},
                                         version => $volume->{version});
$audit->run();
my $volumes = HTFeed::GlacierZipAudit->pending_objects();
foreach my $volume (@$volumes) {
  my $audit = HTFeed::GlacierZipAudit->new(namespace => $volume->{namespace},
                                           objid => $volume->{objid},
                                           path => $volume->{path},
                                           version => $volume->{version});
  my $result = $audit->run();
}
