#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Log { root_logger => 'INFO, screen' };
use HTFeed::BackupExpiration;

if (scalar @ARGV == 1) {
  my $storage_name = $ARGV[0];
  my $exp = HTFeed::BackupExpiration->new(storage_name => $storage_name);
  $exp->run();
} else {
  print "Specify a feed_backups.storage_name value\n";
  exit(0);
}

__END__

=head1 NAME

    expire_backups.pl - remove superseded material from backup storage.

=head1 SYNOPSIS

expire_backups.pl STORAGE_NAME
    
    STORAGE_NAME - storage class name matched against feed_backups.storage_name

=cut
