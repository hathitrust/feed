use Test::Spec;

use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(set_config);
use HTFeed::Volume;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);

describe "HTFeed::PackageType::EPUB::Unpack" => sub {
  my $volume;
  my $ingest_dir;
  my $preingest_dir;
  my $zipfile_dir;
  my $stage;

  before each => sub {
    $ingest_dir = tempdir();
    $preingest_dir = tempdir();
    $zipfile_dir = tempdir();

    set_config(dirname(__FILE__) . "/fixtures/epub",'staging','fetch');
    set_config($ingest_dir,'staging','ingest');
    set_config($preingest_dir,'staging','preingest');
    set_config($zipfile_dir,'staging','zipfile');

    $volume = HTFeed::Volume->new(namespace => 'test',
      objid => 'ark:/87302/t00000001',
      packagetype => 'epub');
    $stage = HTFeed::PackageType::EPUB::Unpack->new(volume => $volume);
  };

  it "succeeds" => sub {
    $stage->run();
    ok($stage->succeeded());
  };

  it "extracts the zip" => sub {
    $stage->run();
    ok(-e "$preingest_dir/ark+=87302=t00000001/test.epub");
  };

  it "extracts the epub contents to ingest/epub_contents" => sub {
    $stage->run();
    ok(-e "$preingest_dir/ark+=87302=t00000001/epub_contents/META-INF/container.xml");
    ok(-e "$preingest_dir/ark+=87302=t00000001/epub_contents/OEBPS/content.opf");
    ok(-e "$preingest_dir/ark+=87302=t00000001/epub_contents/OEBPS/toc.xhtml");
    ok(-e "$preingest_dir/ark+=87302=t00000001/epub_contents/OEBPS/2_chapter-1.xhtml");
  };

  after each => sub {
    $stage->clean();
    rmtree($ingest_dir);
    rmtree($preingest_dir);
    rmtree($zipfile_dir);
  }
};

describe "HTFeed::PackageType::EPUB::SourceMETS" => sub {
};

describe "HTFeed::PackageType::EPUB::VolumeValidator" => sub {
};

describe "HTFeed::PackageType::EPUB::METS" => sub {
};

runtests unless caller;
