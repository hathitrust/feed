package HTFeed::PackageType::IA::DeleteCheck::Test;

use warnings;
use strict;
#use base qw(HTFeed::PackageType::IA::AbstractTest);
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Config qw(set_config);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

# Run DeleteCheck on undamaged package
sub Delete_Check : Test(2){
	
	#my $config = test_config('undamaged');
	set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/download','staging'=>'download');

    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'IA: DeleteCheck succeeded with undamaged package');
	ok($stage->stage_info(), 'IA: DeleteCheck stage info succeeded with undamaged package');	
}

# Test error handling with specific files missing
sub Missing : Test(2){

	#my $config = test_config('damaged');
	set_config('/htapps/test.babel/feed/t/staging/DAMAGED/','staging'=>'download');

	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $ia_id = $volume->get_ia_id();
	my $objdir = $volume->get_download_directory();
	my $scandata = "$objdir/${ia_id}_scandata.xml";
	my $undamaged = "/htapps/test.babel/feed/t/staging/UNDAMAGED";

	# remove $scandata
	unlink($scandata);

	# test stage with $scandata missing
	subtest 'IA: DeleteCheck stage fails with missing file: $scandata' => sub {
		ok(! -e $scandata, 'verify that $scandata is missing...');
		ok(! $stage->run(), '...and IA: DeleteCheck stage fails');
	};
	
	# replace $scandata for next test
	my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_scandata.xml";
	copy($clean_copy,$objdir) or die "copy failed: $!";

}

# test additional warnings
sub Warnings : Test(1){

	#my $config = test_config('damaged');
	set_config('/htapps/test.babel/feed/t/staging/DAMAGED/','staging'=>'download');

	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $ia_id = $volume->get_ia_id();
	my $objdir = $volume->get_download_directory();
	my $damaged = "/htapps/test.babel/feed/t/staging/DAMAGED";
	my $undamaged = "/htapps/test.babel/feed/t/staging/UNDAMAGED";

	#get damaged test package from "samples"
	my $samples = "$damaged/samples/ia/${ia_id}";
	my $broken_scanData = "$samples/${ia_id}_scandata.xml";
	copy($broken_scanData,$objdir) or die "copy failed: $!";

	#run the stage again with damaged package
	# TODO: build additional tests to verify damaged state
	# coverage confirms branches are tested
	ok($stage->run(), 'IA: DeleteCheck succeeds with warnings on damaged package');

	#replace with standard package for next test
	my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_scandata.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";
}

1;

__END__
