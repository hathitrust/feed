# Changes from local pairtree
#
# No need to link (although we could do this by setting obj_dir and link_dir to
# be the same)
#
# object_path should include a date stamp
#
# update_feed_audit should have different behavior (move from Volume?) - record
# to backups table
#
# shouldn't set "repeat" on stage (this could just be a property on the storage
# itself that collate can check)
#
#
package HTFeed::Storage::VersionedPairtree;

use HTFeed::Storage;

use base qw(HTFeed::Storage);
use strict;
use POSIX qw(strftime);
use HTFeed::DBTools qw(get_dbh);

sub object_path {
  my $self = shift;

  $self->{timestamp} ||= strftime("%Y%m%d%H%M%S",gmtime);

  $self->SUPER::object_path('obj_dir') .
    "/" . $self->{timestamp};
}

sub stage_path {
  my $self = shift;

  $self->SUPER::stage_path('obj_dir');
}

sub record_audit {
  my $self = shift;
  $self->record_backup;
}

sub record_backup {
  my $self = shift;

  my $dbh = HTFeed::DBTools::get_dbh();

  my $saved_checksum = HTFeed::VolumeValidator::md5sum($self->zip_obj_path());

  my $stmt =
  "insert into feed_backups (namespace, id, path, version, zip_size, \
    mets_size, saved_md5sum, lastchecked, lastmd5check, md5check_ok) \
    values(?,?,?,?,?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,1)";

  my $sth  = $dbh->prepare($stmt);
  $sth->execute(
      $self->{namespace}, $self->{objid},
      $self->object_path,
      $self->{timestamp}, $self->zip_size,
      $self->mets_size, $saved_checksum);

}

1;
