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

use HTFeed::Storage::PrefixedVersions;
use HTFeed::Storage::ObjectStore;

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

  my $dry_run = $self->{dry_run};
  my $dry_run_text = "";
  $dry_run_text = " (DRY RUN)" if $dry_run;

  my $config = get_config('storage_classes');
  my $storage_config = $config->{$self->{storage_name}};
  die("Can't find storage configuration for " . $self->{storage_name}) unless $storage_config;

  # find everything with more than one version that is at least 6 months old
  # delete all but the most recent > 6 months old version
  my $sth = get_dbh()->prepare(<<'SQL');
    SELECT namespace,id
    FROM feed_backups
    WHERE deleted IS NULL
      AND storage_name=?
      AND version < DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 180 DAY),"%Y%m%d%H%i%S")
    GROUP BY namespace,id
    HAVING COUNT(*) > 1
SQL

  my $versions_sth = get_dbh()->prepare(<<'SQL');
    SELECT version
    FROM feed_backups
    WHERE deleted IS NULL
      AND storage_name=?
      AND namespace=?
      AND id=?
      AND version < DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 180 DAY),"%Y%m%d%H%i%S")
      ORDER BY version DESC
SQL

    my $update_sth = get_dbh()->prepare(<<'SQL');
            UPDATE feed_backups SET deleted=1
            WHERE namespace=?
              AND id=?
              AND version=?
              AND storage_name=?
SQL

  $sth->execute($self->{storage_name});
  while (my $row = $sth->fetchrow_hashref) {
    $versions_sth->execute($self->{storage_name}, $row->{namespace}, $row->{id});
    my @versions = map { $_->[0]; } @{$versions_sth->fetchall_arrayref};
    shift @versions; # jettison the most recent
    foreach my $version (@versions) {
      my $volume = new HTFeed::Volume(namespace => $row->{namespace},
                                      objid => $row->{id},
                                      package_type => 'ht');
      my $storage = $storage_config->{class}->new(volume => $volume,
                                                  config => $storage_config,
                                                  name   => $self->{storage_name});
      unless (defined $storage) {
        die "Unable to get storage for $volume->{namespace}.$volume->{objid}";
      }
      $storage->{timestamp} = $version;
      $storage->{zip_suffix} = '.gpg';
      get_logger->trace("deleting archive for $volume->{namespace}.$volume->{objid} version $version" . $dry_run_text);
      next if $dry_run;
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
