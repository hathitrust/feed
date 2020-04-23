package HTFeed::PackageType::IA::OCRSplit::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use HTFeed::PackageType::IA::OCRSplit;
use HTFeed::Config qw(get_config);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

# Test OCRSplit stage with undamaged package
sub OCRSplit : Test(2){

	test_config('undamaged');

    my $self = shift;
	my $volume = $self->{volume};
  my $stage_dir = $volume->get_staging_directory();
  mkdir($stage_dir);
	my $ia_id = $volume->get_ia_id();
	my $stage = $self->{test_stage};	
	ok($stage->run(),'IA: OCRSplit succeeded with undamaged package');
	ok($stage->stage_info(), 'IA: OCRSPlit stage info succeeded with undamaged package');
}

# Test error handling with missing file
sub Errors : Test(2){

	#load damaged package
	test_config('damaged');

	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $objdir = $volume->get_download_directory();

	my $ia_id = $volume->get_ia_id();

	# Delete djvu.xml, ensure stage fails as expected
	my $xml = "$objdir/${ia_id}_djvu.xml";
	unlink($xml);

    ok(! -e $xml, 'verify that djvu is missing...');
    eval { $stage->run () };

    ok($@ =~ /STAGE_ERROR/, '...and IA: OCRSplit stage fails');
}

# test errors caused by corruputed data
sub usemap : Test(1){

	#load damaged package
	test_config('damaged');

    my $self = shift;
    my $stage = $self->{test_stage};
    my $volume = $self->{volume};
    my $objdir = $volume->get_download_directory();
    mkdir($volume->get_staging_directory());
	my $ia_id =  $volume->get_ia_id();

	#get broken djvu from samples
    my $samples = get_config('test_staging','damaged') . "/samples/ia/${ia_id}";
    my $broken_ocr = "$samples/${ia_id}_djvu.xml";
    copy($broken_ocr,$objdir) or die "copy failed: $!";

    #run the stage again with damaged package
    eval { $stage->run() }  ;
    ok($@ =~ /STAGE_ERROR/, 'IA: OCRSplit fails on damaged package');

    print $stage->stage_info();
}

sub pkgtype { "ia" }

1;

__END__
