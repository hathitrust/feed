#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use YAML::XS;

use lib "$FindBin::Bin/../lib";
use HTFeed::BackupExpirationBatch;
use HTFeed::Log { root_logger => 'INFO, screen' };

my $dry_run = 0; # -d
my $storage_config_file = undef; # -c
my $storage_name = undef; # -s
my $help = 0;

GetOptions(
  'config|c=s' => \$storage_config_file,
  'dry-run|d' => \$dry_run,
  'storage|s=s' => \$storage_name,
  'help|?' => \$help
) or pod2usage(2);
pod2usage(1) if $help;

if (scalar @ARGV != 1) {
  die "path to job file is required";
}

my $storage_config = undef;
if ($storage_config_file) {
  $storage_config = YAML::XS::LoadFile($storage_config_file);
}

my $exp = HTFeed::BackupExpirationBatch->new(
  dry_run => $dry_run,
  job_file => $ARGV[0],
  storage_config => $storage_config,
  storage_name => $storage_name
);
$exp->run();

__END__

=head1 NAME

    expire_versions.pl - remove a batch of superseded material from backup storage.

=head1 SYNOPSIS

expire_versions.pl [--config STORAGE_CONFIG_FILE] [--dry-run] -s STORAGE_NAME PATH_TO_JOB_FILE

    STORAGE_CONFIG_FILE - path to a YAML file with config hash for STORAGE_NAME
    STORAGE_NAME - storage class name matched against feed_backups.storage_name
    PATH_TO_JOB_FILE - path to a TSV file with format namespace<TAB>id<TAB>version
=cut
