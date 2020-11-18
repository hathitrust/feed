use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(mock_zephir);
use HTFeed::Config qw(set_config);

shared_examples_for "an emma mets" => sub { 

  share my %mets_vars;
  my $xc; 

  before each => sub { 
    $xc = $mets_vars{xc};
  };

  it "has remediated fileGrp with the expected number of files" => sub {
    ok($xc->findnodes('//mets:fileGrp[@USE="remediated"]')->size() == 1);
    ok($xc->findnodes('//mets:fileGrp[@USE="remediated"]/mets:file')->size() == 1);
  };

  it "has an empty structmap" => sub {
    ok($xc->findnodes(qq(//mets:div))->size() == 1);
    ok($xc->findnodes(qq(//mets:fptr))->size() == 0);
  };

  it "uses the emma mets profile" => sub {
    ok($xc->findnodes('//mets:mets[@PROFILE="http://www.hathitrust.org/documents/hathitrust-emma-mets-profile1.0.xml"]')->size() == 1);
  };

  it "has a PREMIS message digest calculation event" => sub {
    ok($xc->findnodes('//premis:eventType[text()="message digest calculation"]')->size() == 1);
  };

  it "has a PREMIS virus scan event" => sub {
    ok($xc->findnodes('//premis:eventType[text()="virus scan"]')->size() == 1);
  };

  it "has the EMMA metadata in a dmdSec" => sub {
    ok($xc->findnodes('//mets:dmdSec//emma:SubmissionPackage')->size() == 1);
  };

  it "does not include a reference to MARC metadata" => sub {
    ok($xc->findnodes('//mets:mdref[@MDTYPE="MARC"]')->size() == 0);
  }

};

context "with volume & temporary ingest/preingest/zipfile dirs" => sub {
  my $volume;
  my $objid;
  my $pt_objid;

  my $test_home;
  my $tmpdir;

  my $tmpdirs;

  before all => sub {
    load_db_fixtures;
    $tmpdirs = HTFeed::Test::TempDirs->new();
    $objid = "emmatest";
    $pt_objid = "emmatest";
  };

  before each => sub {
    $tmpdirs->setup_example;
    set_config($tmpdirs->test_home . "/fixtures/emma",'staging','fetch');

    $volume = HTFeed::Volume->new(namespace => 'test',
      objid => $objid,
      packagetype => 'emma');
  };

  after each => sub {
    $tmpdirs->cleanup_example;
  };

  after all => sub {
    $tmpdirs->cleanup;
  };

  describe "HTFeed::PackageType::EMMA::Unpack" => sub {
    my $stage;

    before each => sub {
      $stage = HTFeed::PackageType::EMMA::Unpack->new(volume => $volume);
    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };

    it "extracts the zip" => sub {
      $stage->run();
      ok(-e "$tmpdirs->{ingest}/$pt_objid/foo.txt");
    };

    after each => sub {
      $stage->clean();
    };
  };

  describe "HTFeed::PackageType::EMMA::VirusScan" => sub {
    my $stage;

    before each => sub {
      my $unpack = HTFeed::PackageType::EMMA::Unpack->new(volume => $volume);
      $unpack->run();
      $stage = HTFeed::PackageType::EMMA::VirusScan->new(volume => $volume);

    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };
  };

  describe "HTFeed::PackageType::EMMA::SourceMETS" => sub {
    my $stage;

    before each => sub {
      HTFeed::PackageType::EMMA::Unpack->new(volume => $volume)->run();
      HTFeed::PackageType::EMMA::VirusScan->new(volume => $volume)->run();

      $stage = HTFeed::PackageType::EMMA::SourceMETS->new(volume => $volume);

      mock_zephir();
    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };

    it "generates the METS xml" => sub {
      $stage->run();
      ok(-e "$tmpdirs->{ingest}/$pt_objid/$pt_objid.mets.xml");
    };

    it "caches metadata from the emma xml to the database";

    context "with a mets xml" => sub {
      share my %mets_vars;

      before each => sub {
        $stage->run;
        $mets_vars{xc} = $volume->_parse_xpc("$tmpdirs->{ingest}/$pt_objid/$pt_objid.mets.xml");
      };

      it_should_behave_like "an emma mets";
    };


  };

  describe "HTFeed::PackageType::EMMA::METS" => sub {
    my $stage;

    before each => sub {

      mock_zephir();

      HTFeed::PackageType::EMMA::Unpack->new(volume => $volume)->run();
      HTFeed::PackageType::EMMA::VirusScan->new(volume => $volume)->run();
      HTFeed::PackageType::EMMA::SourceMETS->new(volume => $volume)->run();
      HTFeed::Stage::Pack->new(volume => $volume)->run();

      # expire cached info in volume
      $volume = HTFeed::Volume->new(namespace => 'test',
        objid => $objid,
        packagetype => 'emma');

      $stage = HTFeed::PackageType::EMMA::METS->new(volume => $volume);

    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };

    it "generates the METS xml" => sub {
      $stage->run();
      ok(-e "$tmpdirs->{ingest}/$pt_objid.mets.xml");
    };

    context "with a mets xml" => sub {
      share my %mets_vars;

      before each => sub {
        $stage->run;
        $mets_vars{xc} = $volume->_parse_xpc("$tmpdirs->{ingest}/$pt_objid.mets.xml");
      };


      it_should_behave_like "an emma mets";

    }
  };

};

runtests unless caller;
