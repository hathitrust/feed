package HTFeed::Storage::LinkedPairtree;

use HTFeed::Storage;
use base qw(HTFeed::Storage::LocalPairtree);

use strict;
use Log::Log4perl qw(get_logger);
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);
use HTFeed::VolumeValidator;
use URI::Escape;
use POSIX qw(strftime);
use HTFeed::DBTools qw(get_dbh);

sub stage_path {
  my $self = shift;
  my $volume = shift;

  if(-l $self->link_path) {
    $self->existing_object_tmpdir;
  } else {
    $self->SUPER::stage_path($volume,'obj_dir');
  }
}

sub link_parent {
  my $self = shift;
  my $volume = shift;
  return sprintf('%s/%s/%s',$self->{config}{link_dir},$volume->{namespace},id2ppath($volume->{objid}));
}

sub link_path {
  my $self = shift;
  my $volume = shift;
  my $pt_objid = s2ppchars($volume->{objid});

  return $self->link_parent . $pt_objid;
};

sub symlink_if_needed {
  my $self = shift;

  my $volume = $self->{volume};
  my $namespace = $self->{namespace};
  my $objid = $self->{objid};
  my $pt_objid = s2ppchars($objid);
  $self->{is_repeat} = 0;

  my $link_parent = $self->link_parent;
  my $link_path = $self->link_path;

  if (-l $link_path){
    $self->{object_path} = $self->follow_existing_link;
  }
  else{
    my $object_path = $self->object_path;
    $self->safe_make_path($object_path);
    $self->safe_make_path($link_parent);
    $self->make_link($object_path,$link_path);
  }

  return 1;
}

1;
