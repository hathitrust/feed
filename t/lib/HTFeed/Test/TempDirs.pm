package HTFeed::Test::TempDirs;

use FindBin;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use Cwd qw(abs_path);
use HTFeed::Config qw(set_config get_config);

use warnings;
use strict;

sub new {
  my $class = shift;
  my $test_home = shift;

  my $self = {};
  $self->{test_home} = abs_path($FindBin::Bin);

  $self->{tmpdir} = "$self->{test_home}/test-tmp";
  mkdir("$self->{test_home}/test-tmp");

  return bless ($self, $class);
}

sub test_home {
  my $self = shift;

  return $self->{test_home};
}

sub staging_dirtypes {
  my $self = shift;

  return qw(ingest preingest zipfile zip);
}

sub repo_dirtypes {
  my $self = shift;
  return qw(link_dir obj_dir other_obj_dir backup_obj_dir);
}

sub cleanup {
  my $self = shift;

  remove_tree($self->{tmpdir});
}

sub setup_example {
  my $self = shift;

  my $tmpdir = $self->{tmpdir};

  foreach my $dirtype ($self->staging_dirtypes) {
    $self->{$dirtype} = tempdir("$tmpdir/feed-test-$dirtype-XXXXXX");
    set_config($self->{$dirtype},'staging',$dirtype);
  }

  foreach my $dirtype ($self->repo_dirtypes) {
    $self->{$dirtype} = tempdir("$tmpdir/feed-test-$dirtype-XXXXXX");
    set_config($self->{$dirtype},'repository',$dirtype);
    my $storage_classes = get_config('storage_classes');
    foreach my $storage_class (@$storage_classes) {
      $storage_class->{$dirtype} = $self->{$dirtype};
    }
    set_config($storage_classes,'storage_classes');
  }
}

sub cleanup_example {
  my $self = shift;

  foreach my $dirtype ($self->staging_dirtypes, $self->repo_dirtypes) {
    remove_tree $self->{$dirtype};
  }

}

1;
