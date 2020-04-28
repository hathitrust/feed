use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::SpecSupport;
use HTFeed::Config qw(set_config);

context "with volume & temporary ingest/preingest/zipfile dirs" => sub {
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

  describe "HTFeed::PackageType::Simple::VerifyManifest" => sub {

    context "with a volume with no checksum.md5" => sub {

      it "fails with an error about missing checksum.md5";

    };

    context "with a volume with an empty checksum.md5" => sub {
      it "fails with errors about missing checksum entries" => sub {
        my $volume = HTFeed::Volume->new(namespace => 'test',
          objid => "empty_checksum",
          packagetype => 'simple');

        HTFeed::PackageType::Simple::Unpack->new(volume => $volume)->run();
        HTFeed::PackageType::Simple::VerifyManifest->new(volume => $volume)->run;

        ok($testlog->matches(qr(present in package but not in checksum file)));

      };
    };

    context "with a volume with a checksum missing an entry for meta.yml" => sub {
      it "fails with an error about missing checksum for meta.yml";
    };
  };
};

runtests unless caller;
