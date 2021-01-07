use FindBin;
use lib "$FindBin::Bin/lib";

use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(stage_volume);
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);

local our ($tmpdirs, $testlog);

before all => sub {
  load_db_fixtures;
  $tmpdirs = HTFeed::Test::TempDirs->new();
  $testlog = HTFeed::Test::Logger->new();
};

before each => sub {
  get_dbh()->do("DELETE FROM feed_audit WHERE namespace = 'test'");
  get_dbh()->do("DELETE FROM feed_backups WHERE namespace = 'test'");
  $tmpdirs->setup_example;
  $testlog->reset;
  set_config($tmpdirs->test_home . "/fixtures/volumes",'staging','fetch');
};

after each => sub {
  $tmpdirs->cleanup_example;
};

after all => sub {
  $tmpdirs->cleanup;
};


sub make_old_version {
  my $storage = shift;

  $storage->make_object_path;

  open(my $zip_fh, ">", $storage->zip_obj_path);
  print $zip_fh "old version\n";
  $zip_fh->close;

  open(my $mets_fh,">",$storage->mets_obj_path);
  print $mets_fh "old version\n";
  $mets_fh->close;
}

