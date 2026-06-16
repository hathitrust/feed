#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Log { root_logger => 'INFO, screen' };
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use HTFeed::BackupExpiration;

my $dry_run = 0; # -d
my $storage_name = undef; # -s
my $workers = 1;
my $help = 0;

GetOptions(
  'dry-run|d' => \$dry_run,
  'storage|s=s' => \$storage_name,
  'workers|w=i' => \$workers,
  'help|?' => \$help
) or pod2usage(2);
pod2usage(1) if $help;

$workers = 1 if $workers < 1;

my $exp = HTFeed::BackupExpiration->new(storage_name => $storage_name, dry_run => $dry_run, max_workers => $workers);
$exp->run();

__END__

=head1 NAME

    expire_backups.pl - remove superseded material from backup storage.

=head1 SYNOPSIS

expire_backups.pl [--dry-run] [--workers WORKER_COUNT] -s STORAGE_NAME
    
    STORAGE_NAME - storage class name matched against feed_backups.storage_name
    WORKER_COUNT - maximum number of subprocesses to spawn
=cut
