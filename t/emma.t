use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(mock_zephir);
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);
use File::Path qw(remove_tree);

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

  it "has a PREMIS creation event" => sub {
    ok($xc->findnodes('//premis:eventType[text()="creation"]')->size() == 1);
  };

  it "has a creation date extracted from the EMMA XML" => sub {
    ok($xc->findnodes('//premis:event[premis:eventType[text()="creation"]]/premis:eventDateTime[text()="2020-07-29T16:35:31Z"]')->size() == 1);
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
  };

  it "does not include source metadata" => sub {
    ok($xc->findnodes('//ht:sources')->size() == 0);
  }

};

context "with volume & temporary ingest/preingest/zipfile dirs" => sub {
  my $volume;
  my $objid;
  my $pt_objid;

  my $test_home;
  my $tmpdir;

  my $tmpdirs;
  my $testlog;

  before all => sub {
    load_db_fixtures;
    $tmpdirs = HTFeed::Test::TempDirs->new();
    $testlog = HTFeed::Test::Logger->new();
    $objid = "emmatest";
    $pt_objid = "emmatest";
  };

  before each => sub {
    $tmpdirs->setup_example;
    $testlog->reset;
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

  describe "HTFeed::PackageType::EMMA::Enqueue" => sub {
    use HTFeed::Storage::S3;
    use HTFeed::PackageType::EMMA::Enqueue;

    spec_helper 's3_helper.pl';

    my $fetchdir;
    my $emma_queue;
    my $namespace = get_config('emma','namespace');
    local our ($s3, $bucket);

    before each => sub {
      get_dbh->do("DELETE FROM feed_queue");
      $s3->rm("/","--recursive");

      $fetchdir = $tmpdirs->dir_for("fetch");
      set_config($fetchdir,'staging','fetch');
      mkdir("$fetchdir/$namespace");

      $emma_queue = HTFeed::PackageType::EMMA::Enqueue->new(
        s3 => $s3
      );
    };

    after each => sub {
      remove_tree($fetchdir);
    };

    it "downloads the items in the bucket" => sub {
      my @files = qw(emma_test.zip emma_test.xml emma_test_2.zip emma_test_2.xml);
      put_s3_files(@files);

      $emma_queue->run();

      foreach my $file (@files) {
        ok(-f "$fetchdir/$namespace/$file", "$fetchdir/$namespace/$file");
      }
    };

    it "zips non-zipped stuff" => sub {
      my @files = qw(emma_test.rtf emma_test.xml);
      put_s3_files(@files);

      $emma_queue->run();

      my $results = `unzip -l $fetchdir/$namespace/emma_test.zip`;
      like($results,qr(emma_test\.rtf));
    };

    it "queues the items in the bucket" => sub {
      my @files = qw(emma_test.zip emma_test.xml emma_test_2.zip emma_test_2.xml);
      put_s3_files(@files);

      $emma_queue->run();

      foreach my $id (qw(emma_test emma_test_2)) {
        my $results = get_dbh()->selectrow_arrayref("SELECT COUNT(*) FROM feed_queue WHERE namespace = ? and id = ?",undef,$namespace,$id);
        is($results->[0],1);
      }
    };
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

    context 'with a good volume' => sub {

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

      it "caches metadata from the emma xml to the database" => sub {
        $stage->run();

        my $dbh = get_dbh();

        my $row = $dbh->selectrow_hashref("SELECT * FROM emma_items WHERE remediated_item_id = 'test.emmatest'");

        is($row->{original_item_id},'hvd.32044086819505');
        is($row->{dc_format},'epub');
        is($row->{rem_coverage},'CHAPTERS 1-3, CHAPTERS 5-6, APPENDIX');
        ok($row->{rem_remediation} =~ /REMEDIATION ASPECT/);
      };

      context "with a mets xml" => sub {
        share my %mets_vars;

        before each => sub {
          $stage->run;
          $mets_vars{xc} = $volume->_parse_xpc("$tmpdirs->{ingest}/$pt_objid/$pt_objid.mets.xml");
        };

        it_should_behave_like "an emma mets";
      };
    };

    context 'with mismatched metadata' => sub {
      before each => sub {
        my $volume = HTFeed::Volume->new( namespace => 'test',
          objid => 'bad_id',
          packagetype => 'emma');

        HTFeed::PackageType::EMMA::Unpack->new(volume => $volume)->run();
        HTFeed::PackageType::EMMA::VirusScan->new(volume => $volume)->run();

        $stage = HTFeed::PackageType::EMMA::SourceMETS->new(volume => $volume);

        mock_zephir();
      };

      it "fails with a message about the submission id" => sub {
        eval { $stage->run() };
        ok($testlog->matches(qr(ERROR.*submission_id)));
      };

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

    };
  };

  describe "HTFeed::PackageType::EMMA::Volume" => sub {
    my $fetchdir;

    local our ($s3, $bucket);
    before each => sub {
      $fetchdir = $tmpdirs->dir_for("fetch");
      set_config($fetchdir,'staging','fetch');
      mkdir("$fetchdir/test");
      system("touch","$fetchdir/test/$objid.zip");
      system("touch","$fetchdir/test/$objid.xml");
      my @files = qw(emma_test.zip emma_test.xml);
      put_s3_files(@files);
      set_config($bucket,'emma','bucket');
    };

    after each => sub {
      remove_tree($fetchdir);
    };

    describe "#clean_sip_success" => sub {
      it "moves the zip" => sub {
        $volume->clean_sip_success();

        ok(-e "$tmpdirs->{ingested}/test/$objid.zip");
      };

      it "moves the xml" => sub {
        $volume->clean_sip_success();

        ok(-e "$tmpdirs->{ingested}/test/$objid.xml");
      };

      it "removes everything from the bucket" => sub {
        $volume->clean_sip_success();

        is(scalar @{$s3->list_objects()}, 0);
      };
    };

    describe "#clean_sip_failure" => sub {
      it "moves the zip" => sub {
        $volume->clean_sip_failure();

        ok(-e "$tmpdirs->{punted}/test/$objid.zip");
      };

      it "moves the xml" => sub {
        $volume->clean_sip_failure();

        ok(-e "$tmpdirs->{punted}/test/$objid.xml");
      };
    };

  };

};

runtests unless caller;
