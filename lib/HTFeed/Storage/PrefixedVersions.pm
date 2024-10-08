# Changes from local pairtree
#
# No need to link (although we could do this by setting obj_dir and link_dir to
# be the same)
#
# Path is computed using a prefix of the barcode rather than the complete barcode
#
# Filenames include the date stamp
#
# update_feed_audit should have different behavior (move from Volume?) - record
# to backups table
#
# shouldn't set "repeat" on stage (this could just be a property on the storage
# itself that collate can check)
#
#
package HTFeed::Storage::PrefixedVersions;

use HTFeed::Storage;
use HTFeed::StorageAudit::PrefixedVersions;

use base qw(HTFeed::Storage);
use strict;
use POSIX qw(strftime);
use HTFeed::DBTools qw(get_dbh);
use Log::Log4perl qw(get_logger);

# Class method
sub zip_audit_class {
  my $class = shift;

  return 'HTFeed::StorageAudit::PrefixedVersions';
}

sub delete_objects {
  my $self = shift;

  my $mets = $self->mets_obj_path();
  my $zip = $self->zip_obj_path();
  get_logger->trace("deleting $mets and $zip");
  eval {
    unlink $mets;
    unlink $zip;
  };
  if ($@) {
    get_logger->trace("OPERATION FAILED");
    $self->set_error('OperationFailed',
                     detail => "delete_objects failed: $@");
    return;
  }
  return 1;
}

sub object_path {
  my $self = shift;

  return sprintf('%s/%s/%s',
    $self->{config}->{'obj_dir'},
    $self->{namespace},
    $self->object_prefix);
}

sub object_prefix {
  my $self = shift;
  my $pt_objid = $self->{volume}->get_pt_objid();

  my $prefix_len = length($pt_objid) - 4;
  $prefix_len = 3 if $prefix_len < 3;

  substr($pt_objid,0,$prefix_len);
}

sub stage_path {
  my $self = shift;

  $self->SUPER::stage_path('obj_dir');
}

sub record_audit {
  my $self = shift;
  get_logger->trace("  starting record_audit");
  my $rval = $self->record_backup;
  get_logger->trace("  finished record_audit");

  return $rval;
}

sub verify_crypt {
  # no-op here, since we'll verify we can decrypt it after we copy to staging

  return 1;
}

sub record_backup {
  my $self = shift;

  my $start_time = $self->{job_metrics}->time;
  get_logger->trace("recording backup for $self");
  my $dbh = HTFeed::DBTools::get_dbh();

  my $saved_checksum = HTFeed::VolumeValidator::md5sum($self->zip_obj_path());

  my $stmt =
  "insert into feed_backups (namespace, id, path, version, storage_name,
    zip_size, mets_size, saved_md5sum, lastchecked, lastmd5check, md5check_ok)
    values(?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,1)";

  my $sth = $dbh->prepare($stmt);
  my $res = $sth->execute(
      $self->{namespace},
      $self->{objid},
      $self->audit_path,
      $self->{timestamp},
      $self->{name},
      $self->zip_size,
      $self->mets_size,
      $saved_checksum
  );

  my $end_time   = $self->{job_metrics}->time;
  my $delta_time = $end_time - $start_time;
  $self->{job_metrics}->inc("ingest_record_backup_items_total");
  $self->{job_metrics}->add("ingest_record_backup_seconds_total", $delta_time);

  return $res;
}

sub audit_path {
  my $self = shift;

  return $self->object_path;
}

# Trust that if move succeeds, the object is the same
sub postvalidate {
  my $self = shift;
  my $volume = $self->{volume};

  get_logger->debug("  starting postvalidate");

  foreach my $file ($self->mets_obj_path, $self->zip_obj_path) {
    unless(-f $file) {
      $self->set_error(
        "OperationFailed",
        file => $file,
        operation => 'move',
        detail => 'Target file missing after move'
      );
      return 0;
    }
  }
  get_logger->debug("  finished postvalidate");

  return 1;

}

sub timestamp {
  my $self = shift;

  $self->{timestamp} ||= strftime("%Y%m%d%H%M%S",gmtime);
}

sub mets_filename {
  my $self = shift;

  $self->{volume}->get_pt_objid() . '.' . $self->timestamp . '.mets.xml';
}

sub zip_filename {
  my $self = shift;

  $self->{volume}->get_pt_objid() . '.' . $self->timestamp . $self->zip_suffix;
}

1;
