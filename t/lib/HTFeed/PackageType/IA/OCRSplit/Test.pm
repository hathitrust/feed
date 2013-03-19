package HTFeed::PackageType::IA::OCRSplit::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
#use HTFeed::Config qw(set_config);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

# Test OCRSplit stage with undamaged package
sub OCRSplit : Test(2){

	test_config('undamaged');

    my $self = shift;
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
    ok(! $stage->run(), '...and IA: OCRSplit stage fails');

	#replace djvu for next test
	my $clean_copy = "/htapps/test.babel/feed/t/staging/UNDAMAGED/download/ia/$ia_id/${ia_id}_djvu.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";
}

# test errors caused by corruputed data
sub usemap : Test(1){

	#load damaged package
	test_config('damaged');

    my $self = shift;
    my $stage = $self->{test_stage};
    my $volume = $self->{volume};
    my $objdir = $volume->get_download_directory();
	my $ia_id =  $volume->get_ia_id();

	#get broken djvu from samples
    my $samples = "/htapps/test.babel/feed/t/staging/DAMAGED/samples/ia/${ia_id}";
    my $broken_scanData = "$samples/${ia_id}_djvu.xml";
    copy($broken_scanData,$objdir) or die "copy failed: $!";

    #run the stage again with damaged package
	#TODO: build additional tests to verify damaged state
	# coverage confirms branches are tested
    ok($stage->run(), 'IA: OCRSplit succeeds with warnings on damaged package');

    #replace with standard djvu for next stage test
    my $clean_copy = "/htapps/test.babel/feed/t/staging/UNDAMAGED/download/ia/$ia_id/${ia_id}_djvu.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";

}

1;

__END__
