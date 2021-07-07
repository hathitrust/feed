#!/usr/bin/perl
package HTFeed::StorageZipAudit::ObjectStore;

use strict;
use warnings;
use Carp;
use Log::Log4perl qw(get_logger);
use File::Temp;

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

use base qw(HTFeed::StorageZipAudit);

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
  my $sql = 'SELECT namespace,id,path,version FROM feed_backups' .
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

# Request a single object from Glacier. To keep storage costs down,
# use the restore_request_issued flag to keep the requests under control
# in case something else goes haywire.
sub _request_object {
  my $self = shift;
  my $obj  = shift;

  return if $self->{restore_request_issued};
  my $req_json = '{"Days":10,"GlacierJobParameters":{"Tier":"Bulk"}}';
  $obj->{storage}->{s3}->restore_object($obj->{zip_file}, '--restore-request', $req_json);
  $obj->{storage}->{s3}->restore_object($obj->{mets_file}, '--restore-request', $req_json);
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
  return 0 unless $self->_check_object($obj);
  get_logger->trace("_restore_object: restoring $obj->{zip_file} to $obj->{zip_path}");
  $obj->{storage}->{s3}->get_object($obj->{storage}->{s3}->{'bucket'},
                                     $obj->{zip_file}, $obj->{zip_path});
  get_logger->trace("_restore_object: restoring $obj->{mets_file} to $obj->{mets_path}");
  $obj->{storage}->{s3}->get_object($obj->{storage}->{s3}->{'bucket'},
                                     $obj->{mets_file}, $obj->{mets_path});
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

# Returns 1 only if both zip and METS are ready for download.
sub _check_object {
  my $self = shift;
  my $obj  = shift;

  my $result = $obj->{storage}->{s3}->head_object($obj->{zip_file});
  if ($result->{Restore} && $result->{Restore} =~ m/ongoing-request\s*=\s*"false"/) {
    $result = $obj->{storage}->{s3}->head_object($obj->{mets_file});
    if ($result->{Restore} && $result->{Restore} =~ m/ongoing-request\s*=\s*"false"/) {
      return 1;
    }
  }
  return 0;
}

1;

__END__
