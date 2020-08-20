package HTFeed::Storage;

use strict;
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use File::Path qw(make_path remove_tree);
use File::Pairtree qw(id2ppath s2ppchars);
use HTFeed::VolumeValidator;
use URI::Escape;
use List::MoreUtils qw(uniq);

sub new {
  my $class = shift;

  my $self = {
    config => shift,
  };

  bless($self, $class);
  return $self;
}

sub object_path {
  my $self = shift;
  my $volume = shift;
  my $config_key = shift;

  return sprintf('%s/%s/%s%s',
    $self->{config}->{$config_key},
    $volume->{namespace},
    id2ppath($volume->{objid}),
    s2ppchars($volume->{objid}));
}

sub stage_path_from_base {
  my $self = shift;
  my $volume = shift;
  my $base = shift;

  return sprintf('%s/.tmp/%s.%s',
    $base,
    $volume->{namespace},
    s2ppchars($volume->{objid}));
};

sub stage_path {
  my $self = shift;
  my $volume = shift;
  my $config_key = shift;

  return $self->stage_path_from_base($volume,$self->{config}->{$config_key});
}

sub zip_obj_path {
  my $self = shift;
  my $volume = shift;
  $volume->get_zip_path($self->object_path($volume));
}

sub mets_obj_path {
  my $self = shift;
  my $volume = shift;
  $volume->get_mets_path($self->object_path($volume));
}

sub zip_stage_path {
  my $self = shift;
  my $volume = shift;
  $volume->get_zip_path($self->stage_path($volume));
}

sub mets_stage_path {
  my $self = shift;
  my $volume = shift;
  $volume->get_mets_path($self->stage_path($volume));
}

sub zip_size {
  my $self = shift;
  my $volume = shift;
  my $size = -s $self->zip_obj_path($volume);

  die("Can't get zip size: $!") unless defined $size;

  return $size;
}

sub mets_size {
  my $self = shift;
  my $volume = shift;
  my $size = -s $self->mets_obj_path($volume);

  die("Can't get mets size: $!") unless defined $size;

  return $size;
}

1;
