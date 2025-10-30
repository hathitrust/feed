package HTFeed::Storage::PairtreeObjectStore;

# Stores using the S3 protocol but with pairtree paths

use HTFeed::Storage::ObjectStore;
use base qw(HTFeed::Storage::ObjectStore);

use HTFeed::DBTools qw(get_dbh);
use File::Pairtree qw(id2ppath s2ppchars);

sub object_path {
  my $self = shift;

  return sprintf(
      'obj/%s/%s%s/',
      $self->{namespace},
      id2ppath($self->{objid}),
      s2ppchars($self->{objid})
  );
}

sub zip_key {
    my $self = shift;

    return $self->object_path . $self->{volume}->get_pt_objid() . $self->zip_suffix;

}

sub mets_key {
    my $self = shift;

    return $self->object_path . $self->{volume}->get_mets_filename;
}

sub record_audit {
    my $self = shift;

    my $stmt =
    "insert into feed_storage (namespace, id, storage_name, zip_size, mets_size, saved_md5sum, deposit_time, lastchecked, lastmd5check, md5check_ok) \
    values(?,?,?,?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,1) \
    ON DUPLICATE KEY UPDATE zip_size=?, mets_size=?, saved_md5sum=?, deposit_time=CURRENT_TIMESTAMP, lastchecked = CURRENT_TIMESTAMP,lastmd5check = CURRENT_TIMESTAMP, md5check_ok = 1";

    my $storage_name = $self->{name};
    my $saved_md5sum = $self->saved_md5sum;

    my $zip_size = $self->zip_size;
    my $mets_size = $self->mets_size;

    my $sth      = get_dbh()->prepare($stmt);
    my $res      = $sth->execute(
        $self->{namespace}, $self->{objid}, $storage_name,
        $zipsize, $metssize, $saved_md5sum,
        # duplicate parameters for duplicate key update
        $zipsize, $metssize, $saved_md5sum
    );

    return $res;
}

1;
