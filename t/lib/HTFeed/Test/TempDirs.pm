package HTFeed::Test::TempDirs;

use FindBin;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use Cwd qw(abs_path);
use HTFeed::Config qw(set_config);

use warnings;
use strict;

sub new {
  my $class = shift;
  my $test_home = shift;

  my $self = {};

  $self->{test_home} = abs_path($FindBin::Bin);
  $self->{tmpdir} = tempdir("feed-test-XXXXXX",TMPDIR => 1);
  $self->{dirtypes} = [];

  return bless ($self, $class);
}

sub test_home {
  my $self = shift;
  return $self->{test_home};
}

sub storage_dirtypes {
  return qw(obj_dir backup);
}

sub staging_dirtypes {
  my $self = shift;

  return qw(ingest preingest zipfile zip download ingested punted fetch);
}

sub cleanup {
  my $self = shift;

  remove_tree($self->{tmpdir});
}

sub setup_example {
  my $self = shift;

  foreach my $dirtype ($self->staging_dirtypes) {
    $self->{$dirtype} = $self->dir_for($dirtype);
    set_config($self->{$dirtype},'staging',$dirtype);
  }

  foreach my $dirtype ($self->storage_dirtypes) {
    $self->{$dirtype} = $self->dir_for($dirtype);
  }

  set_config($self->{obj_dir},"repository_root");
}

sub dir_for {
  my $self = shift;
  my $dirtype = shift;

  my $tmpdir = $self->{tmpdir};
  my $subdir = tempdir("$tmpdir/feed-test-$dirtype-XXXXXX");

  $self->{$dirtype} = $subdir;
  push(@{$self->{dirtypes}}, $dirtype);

  return $subdir;
}

sub cleanup_example {
  my $self = shift;

  foreach my $dirtype (@{$self->{dirtypes}}) {
    my $dir = $self->{$dirtype};
    remove_tree $dir if defined $dir and -d $dir;
  }

  $self->{dirtypes} = [];

}

1;
