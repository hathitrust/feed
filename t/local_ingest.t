use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::SpecSupport;
use HTFeed::Config qw(set_config);

sub unpack_and_verify {
  my $objid = shift;
  my $volume = HTFeed::Volume->new(
    namespace => 'test',
    objid => $objid,
    packagetype => 'simple');

  HTFeed::PackageType::Simple::Unpack->new(volume => $volume)->run();
  my $stage = HTFeed::PackageType::Simple::VerifyManifest->new(volume => $volume);
  $stage->run;
  return $stage;
}

describe "HTFeed::PackageType::Simple::VerifyManifest" => sub {
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
    set_config($tmpdirs->test_home . "/fixtures/simple",'staging','fetch');
  };

  after each => sub {
    $tmpdirs->cleanup_example;
  };

  after all => sub {
    $tmpdirs->cleanup;
  };

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

  describe "thumbs.db" => sub {

    it "ignores Thumbs.db when it is in the checksum file but not the package" => sub {
      ok(unpack_and_verify("thumbs_in_checksum")->succeeded());
    };

    it "ignores Thumbs.db when it is in the package but not the checksum file" => sub {
      ok(unpack_and_verify("thumbs_in_pkg")->succeeded());
    };

    it "ignores Thumbs.db when it is in the checksum file and the package, but the checksum is wrong" => sub {
      ok(unpack_and_verify("thumbs_in_checksum_and_pkg_bad_checksum")->succeeded());
    };

    it "ignores Thumbs.db when it is in both the checksum file and the package" => sub {
      ok(unpack_and_verify("thumbs_in_pkg_and_checksum")->succeeded());
    };
  }
};

runtests unless caller;
