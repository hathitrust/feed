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

  $self->SUPER::object_path('backup_obj_dir') .
    "/" . $self->{timestamp};
}

sub stage_path {
  my $self = shift;

  $self->SUPER::stage_path('backup_obj_stage_dir');
}

sub move {
  my $self = shift;

  if( $self->SUPER::move ) {
    $self->record_backup;
  }
}

sub record_backup {
  my $self = shift;

  my $dbh = HTFeed::DBTools::get_dbh();

  my $stmt =
  "insert into feed_backups (namespace, id, version, zip_size, mets_size, lastchecked) values(?,?,?,?,?,CURRENT_TIMESTAMP)";

  my $sth  = $dbh->prepare($stmt);
  $sth->execute(
      $self->{namespace}, $self->{objid},
      $self->{timestamp}, $self->zip_size,
      $self->mets_size);


}

1;
