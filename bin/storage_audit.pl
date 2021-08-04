#!/usr/bin/perl

# Randomly chooses a Data Den or Glacier object to validate against METS and DB.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::StorageAudit;
use HTFeed::Log {root_logger => 'INFO, screen'};

die "Specify a feed_backups.storage_name value" unless 1 == scalar @ARGV;
my $storage_name = $ARGV[0];

my $audit = HTFeed::StorageAudit->for_storage_name($storage_name);
$audit->run_fixity_check();
$audit->run_database_completeness_check();
$audit->run_storage_completeness_check();
