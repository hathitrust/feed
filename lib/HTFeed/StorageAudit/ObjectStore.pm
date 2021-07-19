#!/usr/bin/perl
package HTFeed::StorageAudit::ObjectStore;

use strict;
use warnings;
use Carp;
use Log::Log4perl qw(get_logger);
use File::Temp;

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

use base qw(HTFeed::StorageAudit);

# Layer on top of S3 iterator that de-dupes and translates from AWS keys to storage objects.
sub object_iterator {
  my $self = shift;

  my $s3 = HTFeed::Storage::S3->new(bucket => $self->{storage_config}->{bucket},
                                    awscli => $self->{storage_config}->{awscli});
  my $iterator = $s3->object_iterator;
  my $last_namespace = undef;
  my $last_objid = undef;
  my $last_version = undef;
  return sub {
    my $obj = undef;
    while (!defined $obj) {
      my $object = $iterator->();
      last unless defined $object;

      my ($namespace, $pt_objid, $version, $_rest) = split m/\./, $object->{Key};
      my $objid = HTFeed::StorageAudit::ppchars2s($pt_objid);
      if (!defined $last_namespace || $last_namespace ne $namespace ||
          !defined $last_objid || $last_objid ne $objid ||
          !defined $last_version || $last_version ne $version) {
        $obj = $self->storage_object($namespace, $objid, $version, $object->{Key});
        $last_namespace = $namespace;
        $last_objid = $objid;
        $last_version = $version;
      }
    }
    return $obj;
  }
}

sub storage_object_path {
  my $self = shift;
  my $obj  = shift;

  unless ($obj->{tmpdir}) {
    $obj->{tmpdir} = File::Temp->newdir();
  }
  return $obj->{tmpdir};
}

sub all_objects {
  my $self = shift;

  $self->_request_object($self->random_object());
  my $sql = 'SELECT namespace,id,version,path FROM feed_backups' .
            ' WHERE storage_name=?' .
            ' AND restore_request IS NOT NULL';
  $self->{pending_objects} = [];
  eval {
    my $ref = get_dbh->selectall_arrayref($sql, undef, $self->{storage_name});
    foreach my $row (@$ref) {
      my $obj = $self->storage_object(@$row);
      if (1 == $self->_restore_object($obj)) {
        push @{$self->{pending_objects}}, $obj;
      }
    }
  };
  if ($@) {
    die "Database query failed: $@";
  }
  return $self->{pending_objects};
}

sub is_object_zip_in_storage {
  my $self = shift;
  my $obj  = shift;

  return $obj->{storage}->{s3}->s3_has($obj->{storage}->zip_key);
}

sub is_object_mets_in_storage {
  my $self = shift;
  my $obj  = shift;

  return $obj->{storage}->{s3}->s3_has($obj->{storage}->mets_key);
}

# Request a single object from Glacier. To keep storage costs down,
# use the restore_request_issued flag to keep the requests under control
# in case something else goes haywire.
sub _request_object {
  my $self = shift;
  my $obj  = shift;

  return if $self->{restore_request_issued};
  $obj->{storage}->request_glacier_object();
  my $sql = 'UPDATE feed_backups SET restore_request=CURRENT_TIMESTAMP' .
            ' WHERE namespace=? AND id=? AND version=? AND storage_name=?';
  eval {
    get_dbh()->prepare($sql)->execute($obj->{namespace}, $obj->{objid},
                                      $obj->{version}, $self->{storage_name});
  };
  if ($@) {
    die "Database operation failed: $@";
  }
  $self->{restore_request_issued} = 1;
}

# Returns 1 if both the zip and METS could be restored on the local filesystem.
sub _restore_object {
  my $self = shift;
  my $obj  = shift;

  return 1 if $obj->{restore_complete};
  return 0 unless $obj->{storage}->restore_glacier_object($self->storage_object_path($obj));
  $obj->{restore_complete} = 1;
  my $sql = 'UPDATE feed_backups SET restore_request=NULL' .
            ' WHERE namespace=? AND id=? AND version=? AND storage_name=?';
  eval {
    get_dbh()->prepare($sql)->execute($obj->{namespace}, $obj->{objid},
                                      $obj->{version}, $self->{storage_name});
  };
  if ($@) {
    die "Database operation failed: $@";
  }
  return 1;
}

1;

__END__
