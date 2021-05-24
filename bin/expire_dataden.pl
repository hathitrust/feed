#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Log { root_logger => 'INFO, screen' };
#use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

# Note: if there are several old versions of a volume, this will only
# capture the oldest for removal. My assumption for now is that this
# script will be run frequently enough that stragglers will be cleaned
# up promptly. To get them all, we need a query for each volume detected
# (or a more elegant main query).

# Note sure how the storage_name, config, volume, storage interconnections
# will ultimately be set up.
my $sth = get_dbh()->prepare(<<'SQL');
    SELECT namespace,id,MIN(version),storage_name FROM feed_backups
    WHERE deleted IS NULL AND path LIKE "/htdataden%"
          AND version < DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 180 DAY),"%Y%m%d%H%i%S")
    GROUP BY namespace,id HAVING COUNT(*) > 1
SQL

$sth->execute;
while(my $row = $sth->fetchrow_hashref) {
  my $volume = new HTFeed::Volume(namespace => $row->{namespace},
                                  objid => $row->{objid},
                                  package_type => 'ht');
  my @storages = HTFeed::Storage::for_volume($volume);
  my $volume_storage = undef;
  foreach my $storage (@storages) {
    if ($storage->{name} eq $row->{storage_name}) {
      $volume_storage = $storage;
      last;
    }
  }
  unless (defined $volume_storage) {
    die "Unable to get storage '$row->{storage_name}' for $volume->{namespace}.$volume->{objid}";
  }
  my $update_sth = get_dbh()->prepare(<<'SQL');
      UPDATE feed_backups SET deleted=1
      WHERE namespace=? AND id=? AND version=? AND storage_name=?
SQL
  unless (unlink $volume_storage->mets_filename, $volume_storage->zip_filename) {
    die "Unable to unlink $volume_storage->mets_filename and/or $volume_storage->zip_filename: $!";
  }
  $update_sth->execute($row->{namespace}, $row->{objid},
                       $row->{version}, $row->{storage_name});
}

