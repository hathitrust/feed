package HTFeed::Storage::PairtreeObjectStore;

# Stores using the S3 protocol but with pairtree paths

use HTFeed::Storage::ObjectStore;
use base qw(HTFeed::Storage::ObjectStore);

use File::Pairtree qw(id2ppath s2ppchars);

sub object_path {
  my $self = shift;

  return sprintf(
      '%s/%s%s/',
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
  # noop for now - maybe want to record info on the second site?
  return 1;
}

1;
