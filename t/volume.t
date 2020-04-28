use Test::Spec;

use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(set_config);
use HTFeed::Volume;
use Test::Deep qw(eq_deeply);
use File::Basename qw(dirname);

describe "HTFeed::Volume" => sub {

  my $volume;

  context "an test item " => sub {

    before each => sub {
      set_config(dirname(__FILE__) . "/fixtures/simple",'staging','ingest');
      $volume = HTFeed::Volume->new(namespace => 'test',
        objid => '39015012345678',
        packagetype => 'simple');
    };

    describe "#new" => sub {
      it "returns a HTFeed::PackageType::Simple::Volume" => sub  {
        ok($volume->isa('HTFeed::PackageType::Simple::Volume'));
      }
    };

    describe "#get_namespace" => sub {
      it "returns the namespace" => sub {
        ok($volume->get_namespace eq 'test')
      };
    };

    describe '#objid' => sub {
      it "returns the objid" => sub {
        ok($volume->get_objid eq '39015012345678')
      }
    };

    describe '#get_pt_objid' => sub {
      it "returns the objid" => sub {
        ok($volume->get_pt_objid eq '39015012345678');
      };
    };

    describe '#get_identifier' => sub {
      it "returns the htid" => sub {
        ok($volume->get_identifier eq 'test.39015012345678');
      };
    };

    describe '#get_file_groups' => sub {
      it "returns four file groups" => sub {
        ok(keys(%{$volume->get_file_groups}) == 4);
      };

      it "has a image filegroup with two images" => sub {
        ok(eq_deeply($volume->get_file_groups->{image}->get_filenames(),
          ['00000001.tif', '00000002.jp2']));
      };

      it "has an ocr filegroup with two texts" => sub {
        ok(eq_deeply($volume->get_file_groups->{ocr}->get_filenames(),
          ['00000001.txt', '00000002.txt']));
      };

    };

    describe '#get_all_directory_files' => sub {
      it "returns the content files and the source METS" => sub {
        ok(eq_deeply(sort @{$volume->get_all_directory_files()},
                  qw(00000001.tif 00000001.txt
                    00000002.jp2 00000002.txt 39015012345678.xml)));

      };
    };

    describe '#get_all_content_files' => sub {
      it "returns all files except the source METS" => sub {
        ok(eq_deeply(sort @{$volume->get_all_content_files()},
                  qw(00000001.tif 00000001.txt
                    00000002.jp2 00000002.txt)));

      };
    };

    describe '#get_checksums' => sub {
      it "returns the checksums from the source METS" => sub {
        ok(eq_deeply($volume->get_checksums(),
            {
              '00000001.tif' => '9605a4a4e5c188818669684fded8c57c',
              '00000001.txt' => '9f7c6d752a3bf48fe46bd5702bcc8830',
              '00000002.jp2' => '18d7df30f58bd0f76e7b88e7ca5c3238',
              '00000002.txt' => 'd41d8cd98f00b204e9800998ecf8427e'
            }));
      };
    };

  };

  context "an internet archive item" => sub {
    before each => sub {
      set_config(dirname(__FILE__) . "/fixtures/ia",'staging','ingest');
      $volume = HTFeed::Volume->new(namespace => 'test',
        objid => 'ark:/13960/t00000431',
        packagetype => 'ia');
    };

    describe "#new" => sub {
      it "returns a HTFeed::PackageType::IA::Volume" => sub  {
        ok($volume->isa('HTFeed::PackageType::IA::Volume'));
      }
    };

    describe "#namespace" => sub {
      it "returns the namespace" => sub {
        ok($volume->get_namespace eq 'test')
      };
    };

    describe '#objid' => sub {
      it "returns the objid" => sub {
        ok($volume->get_objid eq 'ark:/13960/t00000431');
      };
    };

    describe '#get_pt_objid' => sub {
      it "transforms filesystem characters per pairtree spec" => sub {
        ok($volume->get_pt_objid eq 'ark+=13960=t00000431');
      };
    };

    describe '#get_identifier' => sub {
      it "returns the htid" => sub {
        ok($volume->get_identifier eq 'test.ark:/13960/t00000431');
      };
    };

    describe '#get_file_groups' => sub {
      it "returns three file groups" => sub {
        ok(keys(%{$volume->get_file_groups}) == 3);
      };

      it "has a image filegroup with two images" => sub {
        eq_deeply($volume->get_file_groups->{image}->get_filenames(),
          ['00000001.jp2', '00000002.jp2']);
      };

      it "has an hocr filegroup with two xmls" => sub {
        eq_deeply($volume->get_file_groups->{hocr}->get_filenames(),
          ['00000001.xml', '00000002.xml']);
      };

      it "has an ocr filegroup with two texts" => sub {
        eq_deeply($volume->get_file_groups->{ocr}->get_filenames(),
          ['00000001.txt', '00000002.txt']);
      };

    };

    describe '#get_all_directory_files' => sub {
      it "returns the content files and the source METS" => sub {
        eq_deeply(sort @{$volume->get_all_directory_files()},
                  qw(00000001.jp2 00000001.txt 00000001.xml
                    00000002.jp2 00000002.txt 00000002.xml IA_ark+=13960=t00000431.xml));

      };
    };

    describe '#get_all_content_files' => sub {
      it "returns all files except the source METS" => sub {
        ok(eq_deeply(sort @{$volume->get_all_content_files()},
                  qw(00000001.jp2 00000001.txt 00000001.xml 
                    00000002.jp2 00000002.txt 00000002.xml)));

      };
    };

    describe '#get_checksums' => sub {
      it "returns the checksums from the source METS" => sub {
        ok(eq_deeply($volume->get_checksums(),
            {
              '00000001.jp2' => '86d8cf7a07c69f75419d2e17ed827ad8',
              '00000002.jp2' => '72e260d0d95d97f3e6f820c2a62169be',
              '00000001.txt' => '9f7c6d752a3bf48fe46bd5702bcc8830',
              '00000002.txt' => 'd41d8cd98f00b204e9800998ecf8427e',
              '00000001.xml' => '0c50017c730339d0bddd2d6e768fb17f',
              '00000002.xml' => '77642ae17243616b513280420d7306b6'
            }));
      }
    }
  };

  context "an epub item" => sub {
    before each => sub {
      set_config(dirname(__FILE__) . "/fixtures/epub",'staging','preingest');
      set_config(dirname(__FILE__) . "/fixtures/epub",'staging','ingest');
      $volume = HTFeed::Volume->new(namespace => 'test',
        objid => 'ark:/87302/t00000001',
        packagetype => 'epub');
    };

    describe "#new" => sub {
      it "returns a HTFeed::PackageType::Simple::Volume" => sub  {
        ok($volume->isa('HTFeed::PackageType::Simple::Volume'));
      }
    };

    describe "#namespace" => sub {
      it "returns the namespace" => sub {
        ok($volume->get_namespace eq 'test')
      };
    };

    describe '#objid' => sub {
      it "returns the objid" => sub {
        ok($volume->get_objid eq 'ark:/87302/t00000001');
      };
    };

    describe '#get_pt_objid' => sub {
      it "transforms filesystem characters per pairtree spec" => sub {
        ok($volume->get_pt_objid eq 'ark+=87302=t00000001');
      };
    };

    describe '#get_identifier' => sub {
      it "returns the htid" => sub {
        ok($volume->get_identifier eq 'test.ark:/87302/t00000001');
      };
    };

    describe '#get_file_groups' => sub {
      it "has a text filegroup with the extracted text" => sub {
        eq_deeply($volume->get_file_groups->{text}->get_filenames(),
          ['00000001.txt', '00000002.txt','00000003.txt','00000004.txt','00000005.txt']);
      };

      it "has an epub filegroup with the epub file" => sub {
        eq_deeply($volume->get_file_groups->{epub}->get_filenames(),
          ['test.epub']);
      };
    };

    describe '#get_checksums' => sub {
      xit "returns the epub and text checksums" => sub {
        ok(eq_deeply($volume->get_checksums(),
            {
              'test.epub'                          => '7195a1c2dc0dea02fca9b39634eb281e',
              # add text...
            }));
      };
    };
  };
};

runtests unless caller;
