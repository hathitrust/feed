use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport;
use HTFeed::Config qw(set_config);

describe "HTFeed::Stage::Collate" => sub {
  my $tmpdirs;
  my $testlog;

  sub collate_item {
    my $tmpdirs = shift;
    my $namespace = shift;
    my $objid = shift;

    my $mets = $tmpdirs->test_home . "/fixtures/collate/$objid.mets.xml";
    my $zip = $tmpdirs->test_home . "/fixtures/collate/$objid.zip";
    system("cp $mets $tmpdirs->{ingest}");
    mkdir("$tmpdirs->{zipfile}/$objid");
    system("cp $zip $tmpdirs->{zipfile}/$objid");

    my $volume = HTFeed::Volume->new(
      namespace => $namespace,
      objid => $objid,
      packagetype => 'simple');

    my $stage = HTFeed::Stage::Collate->new(volume => $volume);
    $stage->run();

    return $stage;

  }

  before all => sub {
    load_db_fixtures;
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
    collate_item($tmpdirs,'test','test');
    ok(-e "/tmp/obj/test/pairtree_root/te/st/test/test.mets.xml");
    ok(-e "/tmp/obj/test/pairtree_root/te/st/test/test.zip");
  };

  it "creates a symlink for the volume" => sub {
    collate_item($tmpdirs,'test','test');
    is("/tmp/obj/test/pairtree_root/te/st/test",readlink("/tmp/obj_link/test/pairtree_root/te/st/test"));
  };

  xit "does not copy or symlink a zip whose checksum does not match the one in the METS to the repository" => sub {
    collate_item($tmpdirs,'test','bad_zip');
    ok(!-e "/tmp/obj/test/pairtree_root/ba/d_/zi/p/bad_zip/bad_zip.mets.xml");
    ok(!-e "/tmp/obj/test/pairtree_root/ba/d_/zi/p/bad_zip/bad_zip.zip");
  };

  it "does not copy or symlink a zip whose contents do not match the METS to the repository";

  it "records the audit with md5 check in feed_audit";
};

runtests unless caller;
