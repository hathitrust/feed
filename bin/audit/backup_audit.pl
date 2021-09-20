#!/usr/bin/perl

# Randomly chooses a Data Den or Glacier object to validate against METS and DB.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use HTFeed::StorageAudit;
use HTFeed::Log {root_logger => 'INFO, screen'};
use Getopt::Long;
use Pod::Usage;

my $fixity = 0;
my $consistency = 0;
my $help = 0;

GetOptions(
  'help|h' => \$help,
  'fixity|f!' => \$fixity,
  'consistency|c!' => \$consistency,
);

pod2usage(1) if $help;
my $storage_name = shift;
pod2usage(1) if not defined $storage_name;
pod2usage(1) unless $fixity or $consistency;

my $audit = HTFeed::StorageAudit->for_storage_name($storage_name);

if($fixity) {
  $audit->run_fixity_check();
}

if($consistency) {
  $audit->run_database_completeness_check();
  $audit->run_storage_completeness_check();
}

=head1 NAME

storage_audit.pl - audit storage consistency and completeness

=head1 SYNOPSIS

storage_audit.pl [--fixity | --consistency] storage_name

storage_name is the name of a configured storage as listed in the
storage_classes configuration key.

OPTIONS

    -f, --fixity - Run a fixity check on the storage as defined by the storage
    class. This involves recalling objects from storage and ensuring they match
    the expected checksum as recorded in the database and/or the METS.
    For offline (tape) storage this selects a single random item to audit.

    -c, --consistency - Runs a storage completeness check and a database completeness check:
    verifies that all the items listed in the database are present in the storage and that
    all the items in storage are listed in the database.

=cut
