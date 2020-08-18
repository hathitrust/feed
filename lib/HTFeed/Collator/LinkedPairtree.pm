package HTFeed::Collator::LinkedPairtree;

use HTFeed::Collator;
use base qw(HTFeed::Collator::LocalPairtree);

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

  if(-l $self->link_path) {
    $self->existing_object_tmpdir;
  } else {
    $self->SUPER::stage_path('obj_dir');
  }
}

sub existing_object_tmpdir {
  my $self = shift;

  my $objdir = $self->follow_existing_link;

  if($objdir =~ qr(^(.*)/$self->{namespace}/pairtree_root/.*)) {
    get_logger()->trace("Using existing object dir $objdir; staging to $1/.tmp");
    return $self->stage_path_from_base($1);
  } else {
    die("Can't determine storage root from existing storage $objdir");
  }

}

sub make_object_path {
  my $self = shift;

  $self->symlink_if_needed;
  $self->set_is_repeat;

  return 1;
}

sub follow_existing_link {
  my $self = shift;

  my $object_path;
  my $link_path = $self->link_path;
  # set object directory to target of existing link
  unless ($object_path = readlink($link_path)){
    # there is no good reason we chould have a dir and no link
    $self->set_error('OperationFailed', operation => 'readlink', file => $link_path, detail => "readlink failed: $!")
  }

  return $object_path;
}

sub make_link {
  my $self = shift;
  my $object_path = shift;
  my $link_path = shift;

  get_logger->trace("Symlinking $object_path to $link_path");
  symlink ($object_path, $link_path)
    or $self->set_error('OperationFailed', operation => 'symlink', detail => "Could not symlink $object_path to $link_path $!");
}

sub link_parent {
  my $self = shift;
  return sprintf('%s/%s/%s',$self->{config}{link_dir},$self->{namespace},id2ppath($self->{objid}));
}

sub link_path {
  my $self = shift;
  my $pt_objid = s2ppchars($self->{objid});

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
