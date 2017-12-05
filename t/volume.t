use Test::Spec;

use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(set_config);
use HTFeed::Volume;
use Test::Deep qw(eq_deeply);
use File::Basename qw(dirname);

describe "HTFeed::Volume" => sub {

  my $volume;

  context "an mdp item " => sub {
  
    before each => sub {
      set_config(dirname(__FILE__) . "/fixtures/google",'staging','ingest');
      $volume = HTFeed::Volume->new(namespace => 'mdp',
        objid => '39015062654291',
        packagetype => 'google');
    };

    describe "#new" => sub {
      it "returns a HTFeed::PackageType::Google::Volume" => sub  {
        ok($volume->isa('HTFeed::PackageType::Google::Volume'));
      }
    };

    describe "#get_namespace" => sub {
      it "returns the namespace" => sub {
        ok($volume->get_namespace eq 'mdp')
      };
    };

    describe '#objid' => sub {
      it "returns the objid" => sub {
        ok($volume->get_objid eq '39015062654291')
      }
    };

    describe '#get_pt_objid' => sub {
      it "returns the objid" => sub {
        ok($volume->get_pt_objid eq '39015062654291');
      };
    };

    describe '#get_identifier' => sub {
      it "returns the htid" => sub {
        ok($volume->get_identifier eq 'mdp.39015062654291');
      };
    };

    describe '#get_file_groups' => sub {
      it "returns three file groups" => sub {
        ok(keys(%{$volume->get_file_groups}) == 3);
      };

      it "has a image filegroup with two images" => sub {
        ok(eq_deeply($volume->get_file_groups->{image}->get_filenames(),
          ['00000001.jp2', '00000002.jp2']));
      };

      it "has an hocr filegroup with two xmls" => sub {
        ok(eq_deeply($volume->get_file_groups->{hocr}->get_filenames(),
          ['00000001.html', '00000002.html']));
      };

      it "has an ocr filegroup with two texts" => sub {
        ok(eq_deeply($volume->get_file_groups->{ocr}->get_filenames(),
          ['00000001.txt', '00000002.txt']));
      };

    };

    describe '#get_all_directory_files' => sub {
      it "returns the content files and the Google METS" => sub {
        ok(eq_deeply(sort @{$volume->get_all_directory_files()},
                  qw(00000001.html 00000001.jp2 00000001.txt 00000002.html
                    00000002.jp2 00000002.txt UOM_39015062654291.xml)));

      };
    };

    describe '#get_all_content_files' => sub {
      it "returns all files except the Google METS" => sub {
        ok(eq_deeply(sort @{$volume->get_all_content_files()},
                  qw(00000001.html 00000001.jp2 00000001.txt 00000002.html
                    00000002.jp2 00000002.txt)));

      };
    };

    describe '#get_checksums' => sub {
      it "returns the checksums from the Google METS" => sub {
        ok(eq_deeply($volume->get_checksums(),
            {
              '00000001.html' => 'b9e4d10d156443b7d52c08e2139d534c',
              '00000001.jp2' => '6ef57d2266bf82de904b77c517009081',
              '00000001.txt' => 'f90637a362570d3ec1323b8a525bb730',
              '00000002.html' => 'd496ecb60e2d374bd3da32ef8f65f065',
              '00000002.jp2' => 'dfee8e767c4b1176a90bcb5b73fa7e0d',
              '00000002.txt' => '3519d4af35b2090ca24b535f3dbe9a19'
            }));
      };
    };

  };

  context "an internet archive item" => sub {
    before each => sub {
      set_config(dirname(__FILE__) . "/fixtures/ia",'staging','ingest');
      $volume = HTFeed::Volume->new(namespace => 'uc2',
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
        ok($volume->get_namespace eq 'uc2')
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
        ok($volume->get_identifier eq 'uc2.ark:/13960/t00000431');
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
};

runtests unless caller;
