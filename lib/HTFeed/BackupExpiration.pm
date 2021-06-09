#!/usr/bin/perl
package HTFeed::BackupExpiration;

use strict;
use warnings;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;
use Carp;
use Log::Log4perl qw(get_logger);
use File::Temp;

sub new {
  my $class = shift;

  my $self = {
    storage_name => undef,
    @_
  };

  unless ($self->{storage_name}) {
    croak "$class cannot be constructed without a storage name";
  }

  bless($self, $class);
  return $self;
}

sub run {
  my $self = shift;

  my $config = get_config('storage_classes');
  my $storage_config = $config->{$self->{storage_name}};
  # Get a list of all volumes with this storage name that have one or more old
  # versions and one or more new versions. This query is about finding sets of
  # volumes, nothing more granular.
  my $sth = get_dbh()->prepare(<<'SQL');
    SELECT namespace,id,MIN(version) AS min_version,MAX(version) AS max_version
    FROM feed_backups
    WHERE deleted IS NULL
      AND storage_name=?
    GROUP BY namespace,id
    HAVING COUNT(*) > 1
      AND min_version < DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 180 DAY),"%Y%m%d%H%i%S")
      AND max_version > DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 180 DAY),"%Y%m%d%H%i%S")
SQL

  $sth->execute($self->{storage_name});
  while (my $row = $sth->fetchrow_hashref) {
    # Get the versions in this group that can be deleted.
    # The previous query has verified that there is >= 1 unexpired version.
    my $versions_sth = get_dbh()->prepare(<<'SQL');
      SELECT version
      FROM feed_backups
      WHERE deleted IS NULL
        AND storage_name=?
        AND namespace=?
        AND id=?
        AND version < DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 180 DAY),"%Y%m%d%H%i%S")
SQL
    $versions_sth->execute($self->{storage_name}, $row->{namespace}, $row->{id});
    foreach my $version (map { $_->[0]; } @{$versions_sth->fetchall_arrayref}) {
      my $volume = new HTFeed::Volume(namespace => $row->{namespace},
                                      objid => $row->{id},
                                      package_type => 'ht');
      my $storage = $storage_config->{class}->new(volume    => $volume,
                                                  config    => $storage_config,
                                                  name      => $self->{storage_name});
      unless (defined $storage) {
        die "Unable to get storage for $volume->{namespace}.$volume->{objid}";
      }
      $storage->{timestamp} = $version;
      my $update_sth = get_dbh()->prepare(<<'SQL');
        UPDATE feed_backups SET deleted=1
        WHERE namespace=?
          AND id=?
          AND version=?
          AND storage_name=?
SQL
      get_logger->trace("deleting archive for $volume->{namespace}.$volume->{objid} version $version");
      unless ($storage->delete_objects) {
        die "Unable to delete $volume->{namespace}.$volume->{objid}";
      }
      get_logger->trace("setting deleted=1 for $volume->{namespace}.$volume->{objid} version $version");
      $update_sth->execute($row->{namespace}, $row->{id},
                           $version, $self->{storage_name});
    }
  }
}

1;

__END__
