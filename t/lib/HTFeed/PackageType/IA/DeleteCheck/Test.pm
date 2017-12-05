package HTFeed::PackageType::IA::DeleteCheck::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use HTFeed::Config qw(get_config);
use HTFeed::PackageType::IA::DeleteCheck;
use File::Copy;
use File::Path qw(make_path);
use Test::More;

# Run DeleteCheck on undamaged package
sub Delete_Check : Test(2){
	
	test_config('undamaged');
  my $self = shift;
	my $volume = $self->{volume};
	my $stage = $self->{test_stage};
  my $preingest = $volume->get_preingest_directory();
  mkdir($volume->get_staging_directory());
  my $ia_id = $volume->get_ia_id();
  my $test_data = get_config('test_data');

  system("unzip -q -o -j -d $preingest $test_data/staging/UNDAMAGED/download/ia/$ia_id/${ia_id}_jp2.zip");

	ok($stage->run(), 'IA: DeleteCheck succeeded with undamaged package');
	ok($stage->stage_info(), 'IA: DeleteCheck stage info succeeded with undamaged package');	
}

# Test error handling with specific files missing
sub Missing : Test(2){

	test_config('damaged');

	my $self = shift;

	my $stage = $self->{test_stage};
	my $volume = $self->{volume};

	my $ia_id = $volume->get_ia_id();
	my $objdir = $volume->get_download_directory();
	my $scandata = "$objdir/${ia_id}_scandata.xml";
	my $undamaged = get_config('test_data') . '/staging/UNDAMAGED';

	# remove $scandata
	unlink($scandata);

	# test stage with $scandata missing
    ok(! -e $scandata, 'verify that $scandata is missing...');
    eval { $stage->run() };
    ok(!$stage->succeeded, '...and IA: DeleteCheck stage fails');
	
	# replace $scandata for next test
	my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_scandata.xml";
	copy($clean_copy,$objdir) or die "copy failed: $!";
}

# test additional warnings
sub Warnings : Test(1){

	test_config('damaged');

	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $ia_id = $volume->get_ia_id();
	my $objdir = $volume->get_download_directory();
	my $damaged = get_config('test_data') . "/staging/DAMAGED";
	my $undamaged = get_config('test_data') . "/staging/UNDAMAGED";

	#get damaged test package from "samples"
	my $samples = "$damaged/samples/ia/${ia_id}";
	my $broken_scanData = "$samples/${ia_id}_scandata.xml";
	copy($broken_scanData,$objdir) or die "copy failed: $!";

	#run the stage again with damaged package
	# TODO: build additional tests to verify damaged state
	# coverage confirms branches are tested
  eval { $stage->run() };
  ok (!$stage->succeeded, 'IA: DeleteCheck fails on damaged package');

	#replace with standard package for next test
	my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_scandata.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";
}

sub pkgtype { 'ia' }
1;

__END__
