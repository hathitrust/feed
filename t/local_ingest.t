use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::SpecSupport qw(mock_zephir);
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Config qw(set_config);
use HTFeed::PackageType::Simple::Unpack;
use HTFeed::PackageType::Simple::VerifyManifest;
use File::Path qw(remove_tree);

sub unpacked_volume {
  my $objid = shift;
  my $volume = HTFeed::Volume->new(
    namespace => 'test',
    objid => $objid,
    packagetype => 'simple');

  HTFeed::PackageType::Simple::Unpack->new(volume => $volume)->run();

  return $volume;
}

sub unpack_and_verify {
  my $objid = shift;
  my $volume = unpacked_volume($objid);
  my $stage = HTFeed::PackageType::Simple::VerifyManifest->new(volume => $volume);
  $stage->run;
  return $stage;
}

describe "HTFeed::PackageType::Simple" => sub {
  my $tmpdirs;
  my $testlog;

  before all => sub {
    load_db_fixtures;
    $tmpdirs = HTFeed::Test::TempDirs->new();
    $testlog = HTFeed::Test::Logger->new();
    set_config(0,'stop_on_error');
  };

  before each => sub {
    $tmpdirs->setup_example;
    $testlog->reset;
    set_config($tmpdirs->test_home . "/fixtures/simple",'staging','fetch');
  };

  after each => sub {
    $tmpdirs->cleanup_example;
  };

  after all => sub {
    $tmpdirs->cleanup;
  };

  describe "checksum.md5" => sub {
    it "reports a relevant error when checksum.md5 is missing" => sub {
      eval { unpack_and_verify("no_checksum"); };
      printf STDERR "EVAL STATUS: $@\n";
      ok($testlog->matches(qr(Missing file.*checksum.md5)));
    };

    it "reports relevant errors when checksum.md5 is empty" => sub {
      unpack_and_verify("empty_checksum");
      ok($testlog->matches(qr(present in package but not in checksum file)));
    };

    it "reports the specific files missing from checksum.md5" => sub {
      unpack_and_verify("missing_meta_yml_checksum");
      ok($testlog->matches(qr(file: meta\.yml.*present in package but not in checksum file)));
    };
  };

  describe "thumbs.db" => sub {

    it "ignores Thumbs.db when it is in the checksum file but not the package" => sub {
      ok(unpack_and_verify("thumbs_in_checksum")->succeeded());
    };

    it "ignores Thumbs.db when it is in the package but not the checksum file" => sub {
      ok(unpack_and_verify("thumbs_in_pkg")->succeeded());
    };

    it "ignores Thumbs.db when it is in the checksum file and the package, but the checksum is wrong" => sub {
      ok(unpack_and_verify("thumbs_bad_checksum")->succeeded());
    };

    it "ignores Thumbs.db when it is in both the checksum file and the package" => sub {
      ok(unpack_and_verify("thumbs_in_pkg_and_checksum")->succeeded());
    };
  };

  describe "meta.yml" => sub {

    before all => sub {
      mock_zephir();
    };

    it "reports a relevant error when meta.yml is missing" => sub {
      my $volume = unpacked_volume("no_meta_yml");
      eval { HTFeed::PackageType::Simple::ImageRemediate->new(volume => $volume)->run(); };

      ok($testlog->matches(qr(Missing file.*meta\.yml)));
    };

    it "reports a relevant error when meta.yml is malformed" => sub {
      my $volume = unpacked_volume("bad_meta_yml");
      eval { HTFeed::PackageType::Simple::SourceMETS->new(volume => $volume)->run(); };
      ok($testlog->matches(qr(File validation failed.*meta\.yml)s));
    }
  };
};

describe "HTFeed::PackageType::Simple::Download" => sub {
  use HTFeed::PackageType::Simple::Download;
  my $tmpdirs;
  my $testlog;
  my $save_rclone;

  before all => sub {
    load_db_fixtures;
    $tmpdirs = HTFeed::Test::TempDirs->new();
    $testlog = HTFeed::Test::Logger->new();
    set_config(0,'stop_on_error');
    set_config(1,'use_dropbox');
    set_config($tmpdirs->test_home . "/fixtures/rclone_config.conf", 'rclone_config_path');
    set_config("$FindBin::Bin/bin/rclone_stub.pl", 'rclone');
  };

  before each => sub {
    $tmpdirs->setup_example;
    $testlog->reset;
  };

  after each => sub {
    $tmpdirs->cleanup_example;
  };

  after all => sub {
    $tmpdirs->cleanup;
    set_config(0,'use_dropbox');
  };

  describe "download stage" => sub {
    it "downloads the file" => sub {
      my $volume = HTFeed::Volume->new(
        namespace => 'test',
        objid => 'test_objid',
        packagetype => 'simple');
      my $download = $volume->get_sip_location();
      my $stage = HTFeed::PackageType::Simple::Download->new(volume => $volume);
      $stage->run();
      ok($stage->succeeded() && -f $download);
    };
  };
};

describe "HTFeed::PackageType::Simple::Volume" => sub {
  use HTFeed::PackageType::Simple::Download;
  my $tmpdirs;
  my $testlog;
  my $fetchdir;

  before all => sub {
    load_db_fixtures;
    $tmpdirs = HTFeed::Test::TempDirs->new();
    $testlog = HTFeed::Test::Logger->new();
    set_config(0,'stop_on_error');
    set_config(1,'use_dropbox');
    set_config($tmpdirs->test_home . "/fixtures/rclone_config.conf", 'rclone_config_path');
    set_config("$FindBin::Bin/bin/rclone_stub.pl", 'rclone');
  };

  before each => sub {
    $tmpdirs->setup_example;
    $testlog->reset;
    $fetchdir = $tmpdirs->dir_for("fetch");
    set_config($fetchdir,'staging','fetch');
    mkdir("$fetchdir/test");
    system("touch","$fetchdir/test/test_objid.zip");
    system("touch","$fetchdir/test/test_objid.xml");
  };

  after each => sub {
    $tmpdirs->cleanup_example;
    remove_tree($fetchdir);
  };

  after all => sub {
    $tmpdirs->cleanup;
    set_config(0,'use_dropbox');
  };

  describe "#clean_sip_success" => sub {
    it "calls rclone to remove SIP from Dropbox" => sub {
      my $volume = HTFeed::Volume->new(
        namespace => 'test',
        objid => 'test_objid',
        packagetype => 'simple');
      eval {
        $volume->clean_sip_success();
      };
      ok($testlog->matches(qr(running.+?rclone.+?delete)i) && !$@);
    };
  };
};

runtests unless caller;
