use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::SpecSupport qw(mock_zephir);
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Config qw(set_config);

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

runtests unless caller;
