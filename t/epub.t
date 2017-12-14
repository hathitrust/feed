use Test::Spec;

use HTFeed::Log {root_logger => 'TRACE, screen'};
use HTFeed::Config qw(set_config);
use HTFeed::Volume;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);
use Cwd qw(abs_path);

sub mock_premis_mets {

  # don't hit the database
  *HTFeed::Volume::record_premis_event = sub {
    1;
  };

  *HTFeed::Volume::get_sources = sub {
    return ( 'ht_test','ht_test','ht_test' );
  };

  # use faked-up marc in case it's missing

  *HTFeed::SourceMETS::_get_marc_from_zephir = sub {
    my $self = shift;
    my $marc_path = shift;

    open(my $fh, ">$marc_path") or die("Can't open $marc_path: $!");

    print $fh <<EOT;
<?xml version="1.0" encoding="UTF-8"?>
<collection xmlns="http://www.loc.gov/MARC21/slim">
<record>
<leader>01142cam  2200301 a 4500</leader>
</record>
</collection>
EOT

    close($fh);

  };

  *HTFeed::Volume::get_event_info = sub {
    return ("some-event-id", "2017-01-01T00:00:00-04:00", undef, undef);
  }
}

context "with volume & temporary ingest/preingest/zipfile dirs" => sub {
  my $volume;
  my $ingest_dir;
  my $preingest_dir;
  my $zipfile_dir;
  my $zip_dir;
  my $objid;
  my $pt_objid;

  my $test_home;
  my $tmpdir;

  before all => sub {
    $test_home = abs_path(dirname(__FILE__));
    $tmpdir = "$test_home/test-tmp";
    mkdir("$test_home/test-tmp");

    $objid = "ark:/87302/t00000001";
    $pt_objid = "ark+=87302=t00000001";
  };

  before each => sub {
    $ingest_dir = tempdir("$tmpdir/feed-test-ingest-XXXXXX");
    $preingest_dir = tempdir("$tmpdir/feed-test-preingest-XXXXXX");
    $zipfile_dir = tempdir("$tmpdir/feed-test-zipfile-XXXXXX");
    $zip_dir = tempdir("$tmpdir/feed-test-zip-XXXXXX");

    set_config($test_home . "/fixtures/epub",'staging','fetch');
    set_config($ingest_dir,'staging','ingest');
    set_config($preingest_dir,'staging','preingest');
    set_config($zipfile_dir,'staging','zipfile');
    set_config($zip_dir,'staging','zip');

    $volume = HTFeed::Volume->new(namespace => 'test',
      objid => $objid,
      packagetype => 'epub');
  };

  after each => sub {
    rmtree($ingest_dir);
    rmtree($preingest_dir);
    rmtree($zipfile_dir);
    rmtree($zip_dir);
  };

  after all => sub {
    rmtree($tmpdir);
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
      ok(-e "$preingest_dir/$pt_objid/test.epub");
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

      # don't hit the database
      *HTFeed::Volume::record_premis_event = sub {
        1;
      }
    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };

    it "moves the expected files" => sub {
      $stage->run();
      ok(! -e "$preingest_dir/$pt_objid/test.epub");
      ok(-e "$ingest_dir/$pt_objid/test.epub");
      ok(! -e "$preingest_dir/$pt_objid/00000001.txt");
      ok(-e "$ingest_dir/$pt_objid/00000001.txt");
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

      mock_premis_mets();
    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };

    it "generates the METS xml" => sub {
      $stage->run();
      ok(-e "$ingest_dir/$pt_objid/$pt_objid.mets.xml");
    };

    context "with a mets xml" => sub {
      my $xc;

      before each => sub {
        $stage->run;
        $xc = $volume->_parse_xpc("$ingest_dir/$pt_objid/$pt_objid.mets.xml");
      };

      it "has epub fileGrp with the expected number of files" => sub {
        ok($xc->findnodes('//mets:fileGrp[@USE="epub"]')->size() == 1);
        ok($xc->findnodes('//mets:fileGrp[@USE="epub"]/mets:file')->size() == 1);
      };
      
      it "has text fileGrp with the expected number of files" => sub {
        ok($xc->findnodes('//mets:fileGrp[@USE="text"]')->size() == 1);
        ok($xc->findnodes('//mets:fileGrp[@USE="text"]/mets:file')->size() == 5);
      };

      it "has contents fileGrp with the expected number of files" => sub {
        ok($xc->findnodes('//mets:fileGrp[@USE="epub contents"]')->size() == 1);
        ok($xc->findnodes('//mets:fileGrp[@USE="epub contents"]/mets:file')->size() == 10);
      };

      it "has contents filegrp with file listing relative path inside epub" => sub {
        ok($xc->findnodes('//mets:fileGrp[@USE="epub contents"]/mets:file/mets:FLocat[@xlink:href="OEBPS/2_chapter-1.xhtml"]')->size() == 1);
      };

      # HTREPO-82 (will need some changes above)
      xit "nests the epub files under the epub in the epub filegrp";
      xit "uses LOCTYPE='URI' for the epub contents";

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


  };

  describe "HTFeed::PackageType::EPUB::METS" => sub {
    my $stage;

    before each => sub {

      mock_premis_mets();

      HTFeed::PackageType::EPUB::Unpack->new(volume => $volume)->run();
      HTFeed::PackageType::EPUB::VerifyManifest->new(volume => $volume)->run();
      HTFeed::PackageType::EPUB::SourceMETS->new(volume => $volume)->run();
      HTFeed::Stage::Pack->new(volume => $volume)->run();

      # expire cached info in volume
      $volume = HTFeed::Volume->new(namespace => 'test',
        objid => $objid,
        packagetype => 'epub');

      $stage = HTFeed::PackageType::EPUB::METS->new(volume => $volume);
      # mocked premis events..
      $stage->{required_events} = ['creation'];
      $HTFeed::PackageType::EPUB::config->{source_premis_events_extract} = ['creation']; 

    };

    it "succeeds" => sub {
      $stage->run();
      ok($stage->succeeded());
    };

    it "generates the METS xml" => sub {
      $stage->run();
      ok(-e "$ingest_dir/$pt_objid.mets.xml");
    };

    context "with a mets xml" => sub {
      my $xc;

      before each => sub {
        $stage->run;
        $xc = $volume->_parse_xpc("$ingest_dir/$pt_objid.mets.xml");
      };

      it "uses the epub mets profile" => sub {
        ok($xc->findnodes('//mets:mets[@PROFILE="http://www.hathitrust.org/documents/hathitrust-epub-mets-profile1.0.xml"]')->size() == 1);
      };
    }
  };

};

describe "HTFeed::PackageType::EPUB::VolumeValidator" => sub {
  xit "succeeds";
};


runtests unless caller;
