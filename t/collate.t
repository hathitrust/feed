use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::SpecSupport;
use HTFeed::Config qw(set_config);

describe "HTFeed::Stage::Collate" => sub {
  my $tmpdirs;
  my $testlog;

  before all => sub {
    $tmpdirs = HTFeed::Test::TempDirs->new();
    $testlog = HTFeed::Test::Logger->new();
    set_config(0,'stop_on_error');
  };

  before each => sub {
    $tmpdirs->setup_example;
    $testlog->reset;
    set_config($tmpdirs->test_home . "/fixtures/collate",'staging','fetch');
  };

  after each => sub {
    $tmpdirs->cleanup_example;
  };

  after all => sub {
    $tmpdirs->cleanup;
  };

  it "copies the mets and zip to the repository" => sub {
    my $mets = $tmpdirs->test_home . "/fixtures/collate/test.mets.xml";
    my $zip = $tmpdirs->test_home . "/fixtures/collate/test.zip";
    system("cp $mets $tmpdirs->{ingest}");
    mkdir("$tmpdirs->{zipfile}/test");
    system("cp $zip $tmpdirs->{zipfile}/test");

    my $volume = HTFeed::Volume->new(
      namespace => 'test',
      objid => 'test',
      packagetype => 'simple');

    HTFeed::Stage::Collate->new(volume => $volume)->run();
    ok(-e "/tmp/obj/test/pairtree_root/te/st/test/test.mets.xml");
    ok(-e "/tmp/obj/test/pairtree_root/te/st/test/test.zip");
  };
};

runtests unless caller;
