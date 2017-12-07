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

  context "an epub item" => sub {
    before each => sub {
      set_config(dirname(__FILE__) . "/fixtures/epub",'staging','preingest');
      set_config(dirname(__FILE__) . "/fixtures/epub",'staging','ingest');
      $volume = HTFeed::Volume->new(namespace => 'test',
        objid => 'ark:/87302/t00000001',
        packagetype => 'epub');
    };

    describe "#new" => sub {
      it "returns a HTFeed::PackageType::EPUB::Volume" => sub  {
        ok($volume->isa('HTFeed::PackageType::EPUB::Volume'));
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

      it "has an epub_contents filegroup with the epub contents" => sub {
        eq_deeply(sort @{$volume->get_file_groups->{epub_contents}->get_filenames()},
          ('META-INF/container.xml',
            'mimetype',
            'OEBPS/0_no-title.xhtml',
            'OEBPS/1_no-title.xhtml',
            'OEBPS/2_chapter-1.xhtml',
            'OEBPS/3_chapter-2.xhtml',
            'OEBPS/content.opf',
            'OEBPS/style.css',
            'OEBPS/toc.ncx'));
      };

    };

    describe '#get_epub_path' => sub {
      it "returns the path to the epub" => sub {
        ok($volume->get_epub_path() =~ /test.epub$/);
      };
    };
#
#    describe '#get_all_directory_files' => sub {
#      it "returns the content files and the source METS" => sub {
#        eq_deeply(sort @{$volume->get_all_directory_files()},
#                  qw(00000001.jp2 00000001.txt 00000001.xml
#                    00000002.jp2 00000002.txt 00000002.xml IA_ark+=13960=t00000431.xml));
#
#      };
#    };
#
#    describe '#get_all_content_files' => sub {
#      it "returns all files except the source METS" => sub {
#        ok(eq_deeply(sort @{$volume->get_all_content_files()},
#                  qw(00000001.jp2 00000001.txt 00000001.xml 
#                    00000002.jp2 00000002.txt 00000002.xml)));
#
#      };
#    };
#
    describe '#get_checksums' => sub {
      xit "returns the epub checksum as well as the checksums of files inside it" => sub {
        ok(eq_deeply($volume->get_checksums(),
            {
              'test.epub'                          => '7195a1c2dc0dea02fca9b39634eb281e',
              'test.epub/META-INF/container.xml'   => 'bc793f50d0ec7ff556193c109f5d3afc',
              'test.epub/mimetype'                 => '4154e1f4f9c0e002cc44aae97103ebe2',
              'test.epub/OEBPS/0_no-title.xhtml'   => 'fe665af3bfddabaf1837e46e12057e9d',
              'test.epub/OEBPS/1_no-title.xhtml'   => 'fe1535d9c820f33dac8278ef05760ee4',
              'test.epub/OEBPS/2_chapter-1.xhtml'  => 'b46505d4c242e9cc5f7bc7e20d8f0bf4',
              'test.epub/OEBPS/3_chapter-2.xhtml'  => '715ed5c3ff6c577c211c5c6ae7aa51d2',
              'test.epub/OEBPS/content.opf'        => '31447aba266a1c2918d8c2ee0698ef61',
              'test.epub/OEBPS/style.css'          => '26863d0ac59ed4bacdeffaf62b102808',
              'test.epub/OEBPS/toc.ncx'            => '57b388186ba815f372537bfba8bf500e',
              'test.epub/OEBPS/toc.xhtml'          => '3d9defd76447ffe2bf88c9ed3093d2ae',
            }));
      };
    };
  };
};

runtests unless caller;
