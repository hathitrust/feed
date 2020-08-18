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

  my %args = @_;

  die("Missing required argument 'config'")
    unless $args{config};

  my $config = $args{config};

  my $self = {
    config => $config,
  };

  bless($self, $class);
  return $self;
}

sub object_path {
  my $self = shift;
  my $config_key = shift;

  return sprintf('%s/%s/%s%s',
    $self->{config}->{$config_key},
    $self->{namespace},
    id2ppath($self->{objid}),
    s2ppchars($self->{objid}));
}

sub stage_path_from_base {
  my $self = shift;
  my $base = shift;

  return sprintf('%s/.tmp/%s.%s',
    $base,
    $self->{namespace},
    s2ppchars($self->{objid}));
};

sub stage_path {
  my $self = shift;
  my $config_key = shift;

  return $self->stage_path_from_base($self->{config}->{$config_key});
}

sub zip_obj_path {
  my $self = shift;
  my $volume = shift;
  $volume->get_zip_path($self->object_path());
}

sub mets_obj_path {
  my $self = shift;
  my $volume = shift;
  $volume->get_mets_path($self->object_path());
}

sub zip_stage_path {
  my $self = shift;
  my $volume = shift;
  $volume->get_zip_path($self->stage_path());
}

sub mets_stage_path {
  my $self = shift;
  my $volume = shift;
  $volume->get_mets_path($self->stage_path());
}

sub zip_size {
  my $self = shift;
  my $size = -s $self->zip_obj_path;

  die("Can't get zip size: $!") unless defined $size;

  return $size;
}

sub mets_size {
  my $self = shift;
  my $size = -s $self->mets_obj_path;

  die("Can't get mets size: $!") unless defined $size;

  return $size;
}

1;
