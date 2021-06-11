#!/usr/bin/perl

# Randomly chooses a Data Den object to validate against METS and DB.
# This script should be run hourly, give or take.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::DataDenZipAudit;
use HTFeed::Log {root_logger => 'INFO, screen'};

die "Specify a feed_backups.storage_name value" unless 1 == scalar @ARGV;
my $storage_name = $ARGV[0];

my $volume = HTFeed::DataDenZipAudit::choose($storage_name);
if (defined $volume->{namespace} && defined $volume->{objid} &&
    defined $volume->{path} && defined $volume->{version}) {
  my $audit = HTFeed::DataDenZipAudit->new(%$volume);
  $audit->run();
}
