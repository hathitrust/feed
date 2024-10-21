use FindBin;
use lib "$FindBin::Bin/lib";

use strict;
use warnings;

use HTFeed::Config qw(set_config);
use HTFeed::Test::SpecSupport qw(mock_zephir);
use HTFeed::Test::Support qw(load_db_fixtures);
use Test::Spec;

context "mock download" => sub {
    describe "HTFeed::PackageType::IA::Download" => sub {
	use HTFeed::JobMetrics;
	it "increments jobmetrics (even as a mock download)" => sub {
	    my $jm     = HTFeed::JobMetrics->new;
	    my $objid  = 'ark:/13960/t7kq2zj36';
	    my $ia_id  = 'ark+=13960=t7kq2zj36';
	    my $volume = HTFeed::Volume->new(
		namespace   => 'test',
		objid       => $objid,
		packagetype => 'ia'
	    );
	    my $download_items = "ingest_download_items_total";

	    $jm->clear;
	    $volume->{ia_id} = $ia_id;
	    my $downloader   = HTFeed::PackageType::IA::Download->new(volume => $volume);
	    my @mock_files   = (
		'djvu.xml',
		'files.xml',
		'jp2.zip',
		'meta.xml',
		'scandata.xml',
		'scanfactors.xml',
	    );
	    # Create mock files in the download dir to skip the actual download from IA
	    foreach my $mock_file (@mock_files) {
		my $mock_path = join(
		    "",
		    $volume->get_download_directory(),
		    "/",
		    $ia_id,
		    "_",
		    $mock_file
		);
		system("touch $mock_path");
	    }

	    # Check that the $download_items metric increments upon successful download
	    ok($jm->get_value($download_items) == 0);
	    $downloader->run();
	    ok($jm->get_value($download_items) == 1);
	};
    };
};

context "with volume & temporary ingest/preingest/zipfile dirs" => sub {
    my $volume;
    my $objid;
    my $pt_objid;
    my $tmpdir;
    my $tmpdirs;

    before all => sub {
	load_db_fixtures;
	$tmpdirs  = HTFeed::Test::TempDirs->new();
	$objid    = 'ark:/13960/t7kq2zj36';
	$pt_objid = 'ark+=13960=t7kq2zj36';
    };

    before each => sub {
	$tmpdirs->setup_example;
	set_config($tmpdirs->test_home . '/fixtures', 'staging', 'download');

	$volume = HTFeed::Volume->new(
	    namespace   => 'test',
	    objid       => $objid,
	    packagetype => 'ia'
	);
	$volume->{ia_id} = 'ark+=13960=t7kq2zj36';
    };

    after each => sub {
	$tmpdirs->cleanup_example;
    };

    after all => sub {
	$tmpdirs->cleanup;
    };

    describe "HTFeed::PackageType::IA::VerifyManifest" => sub {
	my $stage;

	before each => sub {
	    HTFeed::PackageType::IA::Unpack->new(volume => $volume)->run();
	    $stage = HTFeed::PackageType::IA::VerifyManifest->new(volume => $volume);
	};

	it "succeeds" => sub {
	    $stage->run();
	    ok($stage->succeeded());
	};

	after each => sub {
	    $stage->clean();
	};
    };

    describe "HTFeed::PackageType::IA::Unpack" => sub {
	my $stage;

	before each => sub {
	    $stage = HTFeed::PackageType::IA::Unpack->new(volume => $volume);
	};

	it "succeeds" => sub {
	    $stage->run();
	    ok($stage->succeeded());
	};

	it "extracts the zip" => sub {
	    $stage->run();

	    my $ia_id = $volume->get_ia_id();
	    ok(-e "$tmpdirs->{preingest}/$pt_objid/${ia_id}_0001.jp2");
	};

	after each => sub {
	    $stage->clean();
	};
    };

    share my %vars;
    shared_examples_for "mets with reading order" => sub {
	it "succeeds" => sub {
	    my $stage = $vars{stage};
	    $stage->run();
	    ok($stage->succeeded());
	};

	it "generates the METS xml" => sub {
	    $vars{stage}->run();
	    ok(-e $vars{mets_xml});
	};

	context "with a mets xml" => sub {

	    before each => sub {
		$vars{stage}->run;
	    };

	    it "writes scanningOrder, readingOrder, and coverTag" => sub {
		my $xc           = $volume->_parse_xpc($vars{mets_xml});
		my $xpath_prefix = '/METS:mets/METS:amdSec/METS:techMD/METS:mdWrap/METS:xmlData';
		ok($xc->findnodes("$xpath_prefix/gbs:scanningOrder")->size() == 1);
		is($xc->findvalue("$xpath_prefix/gbs:scanningOrder"), 'right-to-left');
		ok($xc->findnodes("$xpath_prefix/gbs:readingOrder")->size() == 1);
		is($xc->findvalue("$xpath_prefix/gbs:readingOrder"), 'right-to-left');
		ok($xc->findnodes("$xpath_prefix/gbs:coverTag")->size() == 1);
		is($xc->findvalue("$xpath_prefix/gbs:coverTag"), 'follows-reading-order');
	    };
	};
    };

    describe "HTFeed::PackageType::IA::SourceMETS" => sub {

	before each => sub {
	    $volume->record_premis_event('package_inspection');
	    HTFeed::PackageType::IA::VerifyManifest->new(volume => $volume)->run();
	    HTFeed::PackageType::IA::Unpack->new(volume => $volume)->run();
	    HTFeed::PackageType::IA::DeleteCheck->new(volume => $volume)->run();
	    HTFeed::PackageType::IA::OCRSplit->new(volume => $volume)->run();
	    HTFeed::PackageType::IA::ImageRemediate->new(volume => $volume)->run();
	    mock_zephir();
	    $vars{stage}    = HTFeed::PackageType::IA::SourceMETS->new(volume => $volume);
	    $vars{mets_xml} = "$tmpdirs->{ingest}/$pt_objid/IA_$pt_objid.xml"
	};

	it_should_behave_like "mets with reading order";
    };

    describe "HTFeed::PackageType::IA::METS" => sub {
	before each => sub {
	    $volume->record_premis_event('package_inspection');
	    HTFeed::PackageType::IA::VerifyManifest->new(volume => $volume)->run();
	    HTFeed::PackageType::IA::Unpack->new(volume => $volume)->run();
	    HTFeed::PackageType::IA::DeleteCheck->new(volume => $volume)->run();
	    HTFeed::PackageType::IA::OCRSplit->new(volume => $volume)->run();
	    HTFeed::PackageType::IA::ImageRemediate->new(volume => $volume)->run();
	    mock_zephir();
	    HTFeed::PackageType::IA::SourceMETS->new(volume => $volume)->run();
	    HTFeed::VolumeValidator->new(volume => $volume)->run();
	    HTFeed::Stage::Pack->new(volume => $volume)->run();
	    $vars{stage}    = HTFeed::METS->new(volume => $volume);
	    $vars{mets_xml} = "$tmpdirs->{ingest}/$pt_objid.mets.xml"
	};

	it_should_behave_like "mets with reading order";
    };
};

runtests unless caller;
