use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(mock_zephir);
use HTFeed::Config qw(set_config);

shared_examples_for "an epub mets" => sub { 

  share my %mets_vars;
  my $xc; 

  before each => sub { 
    $xc = $mets_vars{xc};
  };

  it "has epub fileGrp with the expected number of files" => sub {
    ok($xc->findnodes('//mets:fileGrp[@USE="epub"]')->size() == 1);
    ok($xc->findnodes('//mets:fileGrp[@USE="epub"]/mets:file')->size() == 1);
  };

  it "has text fileGrp with the expected number of files" => sub {
    ok($xc->findnodes('//mets:fileGrp[@USE="text"]')->size() == 1);
    ok($xc->findnodes('//mets:fileGrp[@USE="text"]/mets:file')->size() == 5);
  };

  it "has epub fileGrp with nested contents" => sub {
    ok($xc->findnodes('//mets:fileGrp[@USE="epub"]/mets:file/mets:file')->size() == 10);
  };

  it "has epub filegrp with file listing relative path inside epub" => sub {
    ok($xc->findnodes('//mets:fileGrp[@USE="epub"]/mets:file/mets:file/mets:FLocat[@xlink:href="OEBPS/2_chapter-1.xhtml"]')->size() == 1);
  };

  # HTREPO-82 (will need some changes above)
  it "uses LOCTYPE='URL' for the epub contents" => sub {
    ok($xc->findnodes('//mets:fileGrp[@USE="epub"]/mets:file/mets:file/mets:FLocat[@LOCTYPE="URL"]')->size() == 10);
    ok($xc->findnodes('//mets:fileGrp[@USE="epub"]/mets:file/mets:file/mets:FLocat[@OTHERLOCTYPE]')->size() == 0);
  };

  it "does not include checksums for the epub contents" => sub {
    ok($xc->findnodes('//mets:fileGrp[@USE="epub"]/mets:file/mets:file[@CHECKSUM]')->size() == 0);
    ok($xc->findnodes('//mets:fileGrp[@USE="epub"]/mets:file/mets:file[@CHECKSUMTYPE]')->size() == 0);
  };

  it "links text and xhtml in the structmap based on the spine" => sub {
    # file 00000004.txt and file OEBPS/2_chapter-1.xhtml should be under the same div in the structmap
    my @txt_xhtml_links = ( ['00000001.txt', 'OEBPS/0_no-title.xhtml'],
      ['00000002.txt', 'OEBPS/1_no-title.xhtml'],
      ['00000003.txt', 'OEBPS/toc.xhtml'],
      ['00000004.txt', 'OEBPS/2_chapter-1.xhtml'],
      ['00000005.txt', 'OEBPS/3_chapter-2.xhtml'] );

    foreach my $link (@txt_xhtml_links) {
      my ($txt,$xhtml) = @$link;
      ok($xc->findnodes(qq(//mets:div[mets:fptr[\@FILEID=//mets:file[mets:FLocat[\@xlink:href="$txt"]]/\@ID]][mets:fptr[\@FILEID=//mets:file[mets:FLocat[\@xlink:href="$xhtml"]]/\@ID]]))->size() == 1);
    }
  };

  it "has sequential seqs for the text files" => sub {
    ok($xc->findnodes('//mets:fileGrp[@USE="text"]/mets:file[@SEQ="00000001"]/mets:FLocat[@xlink:href="00000001.txt"]')->size() == 1);
    ok($xc->findnodes('//mets:fileGrp[@USE="text"]/mets:file[@SEQ="00000002"]/mets:FLocat[@xlink:href="00000002.txt"]')->size() == 1);
  };

  it "uses the chapter title from meta.yml as the div label" => sub {
    ok($xc->findnodes('//mets:div[mets:fptr[@FILEID=//mets:file[mets:FLocat[@xlink:href="OEBPS/2_chapter-1.xhtml"]]/@ID]][@LABEL="Chapter 1"]')->size() == 1);
    ok($xc->findnodes('//mets:div[mets:fptr[@FILEID=//mets:file[mets:FLocat[@xlink:href="OEBPS/3_chapter-2.xhtml"]]/@ID]][@LABEL="Chapter 2"]')->size() == 1);
  };

  it "uses the epub mets profile" => sub {
    ok($xc->findnodes('//mets:mets[@PROFILE="http://www.hathitrust.org/documents/hathitrust-epub-mets-profile1.0.xml"]')->size() == 1);
  };

  it "has a PREMIS creation event" => sub {
    ok($xc->findnodes('//premis:eventType[text()="creation"]')->size() == 1);
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
    $objid = "ark:/87302/t00000001";
    $pt_objid = "ark+=87302=t00000001";
  };

  before each => sub {
    $tmpdirs->setup_example;
    set_config($tmpdirs->test_home . "/fixtures/epub",'staging','fetch');

    $volume = HTFeed::Volume->new(namespace => 'test',
      objid => $objid,
      packagetype => 'epub');
  };

  after each => sub {
    $tmpdirs->cleanup_example;
  };

  after all => sub {
    $tmpdirs->cleanup;
  };

  describe "HTFeed::PackageType::EPUB::Unpack" => sub {
    my $stage;

    before each => sub {
      $stage = HTFeed::PackageType::EPUB::Unpack->new(volume => $volume);
    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };

    it "extracts the zip" => sub {
      $stage->run();
      ok(-e "$tmpdirs->{preingest}/$pt_objid/test.epub");
    };

    after each => sub {
      $stage->clean();
    };
  };

  describe "HTFeed::PackageType::EPUB::VerifyManifest" => sub {
    my $stage;

    before each => sub {
      HTFeed::PackageType::EPUB::Unpack->new(volume => $volume)->run();
      $stage = HTFeed::PackageType::EPUB::VerifyManifest->new(volume => $volume);
    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };

    it "moves the expected files" => sub {
      $stage->run();
      ok(! -e "$tmpdirs->{preingest}/$pt_objid/test.epub");
      ok(-e "$tmpdirs->{ingest}/$pt_objid/test.epub");
      ok(! -e "$tmpdirs->{preingest}/$pt_objid/00000001.txt");
      ok(-e "$tmpdirs->{ingest}/$pt_objid/00000001.txt");
    };

    after each => sub {
      $stage->clean();
    };
  };

  describe "HTFeed::PackageType::EPUB::SourceMETS" => sub {
    my $stage;

    before each => sub {
      HTFeed::PackageType::EPUB::Unpack->new(volume => $volume)->run();
      HTFeed::PackageType::EPUB::VerifyManifest->new(volume => $volume)->run();

      $stage = HTFeed::PackageType::EPUB::SourceMETS->new(volume => $volume);

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

    context "with a mets xml" => sub {
      share my %mets_vars;

      before each => sub {
        $stage->run;
        $mets_vars{xc} = $volume->_parse_xpc("$tmpdirs->{ingest}/$pt_objid/$pt_objid.mets.xml");
      };

      it_should_behave_like "an epub mets";
    };


  };

  describe "HTFeed::PackageType::EPUB::METS" => sub {
    my $stage;

    before each => sub {

      mock_zephir();

      HTFeed::PackageType::EPUB::Unpack->new(volume => $volume)->run();
      HTFeed::PackageType::EPUB::VerifyManifest->new(volume => $volume)->run();
      HTFeed::PackageType::EPUB::SourceMETS->new(volume => $volume)->run();
      HTFeed::Stage::Pack->new(volume => $volume)->run();

      # expire cached info in volume
      $volume = HTFeed::Volume->new(namespace => 'test',
        objid => $objid,
        packagetype => 'epub');

      # not running volume validation, but we need to record a premis event for it
      # to make the METS happy
      $volume->record_premis_event( 'package_validation' );

      $stage = HTFeed::PackageType::EPUB::METS->new(volume => $volume);

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


      it_should_behave_like "an epub mets";

    }
  };
  describe "HTFeed::PackageType::EPUB::VolumeValidator" => sub {
    my $stage;
    before each => sub {

      mock_zephir();

      HTFeed::PackageType::EPUB::Unpack->new(volume => $volume)->run();
      HTFeed::PackageType::EPUB::VerifyManifest->new(volume => $volume)->run();
      HTFeed::PackageType::EPUB::SourceMETS->new(volume => $volume)->run();

      # expire cached info in volume
      $volume = HTFeed::Volume->new(namespace => 'test',
        objid => $objid,
        packagetype => 'epub');

      $stage = HTFeed::PackageType::EPUB::VolumeValidator->new(volume => $volume);

    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };
  };

};



runtests unless caller;
