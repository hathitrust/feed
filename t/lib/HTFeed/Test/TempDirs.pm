package HTFeed::Test::TempDirs;

use FindBin;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);
use Cwd qw(abs_path);
use HTFeed::Config qw(set_config);

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

sub dirtypes {
  my $self = shift;

  return qw(ingest preingest zipfile zip);
}

sub cleanup {
  my $self = shift;

  rmtree($self->{tmpdir});
}

sub setup_example {
  my $self = shift;

  my $tmpdir = $self->{tmpdir};

  foreach my $dirtype ($self->dirtypes) {
    $self->{$dirtype} = tempdir("$tmpdir/feed-test-$dirtype-XXXXXX");
    set_config($self->{$dirtype},'staging',$dirtype);
  }
}

sub cleanup_example {
  my $self = shift;

  foreach my $dirtype ($self->dirtypes) {
    rmtree $self->{$dirtype};
  }

}

1;
