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

die "Specify a feed_backups.storage_name value" unless 1 == scalar @ARGV;
my $storage_name = $ARGV[0];

my $volume = HTFeed::GlacierZipAudit::choose($storage_name);
if (defined $volume->{namespace} && defined $volume->{objid} &&
    defined $volume->{path} && defined $volume->{version}) {
  my $audit = HTFeed::GlacierZipAudit->new(%$volume);
  $audit->run();
}
my $volumes = HTFeed::GlacierZipAudit->pending_objects($storage_name);
foreach my $volume (@$volumes) {
  my $audit = HTFeed::GlacierZipAudit->new(%$volume);
  my $result = $audit->run();
}
