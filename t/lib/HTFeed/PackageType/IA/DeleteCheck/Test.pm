package HTFeed::PackageType::IA::DeleteCheck::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub get_scandada : Test(setup){
	#TODO unify setup method with config file
	# point to 'damaged' & 'undamaged'
}

sub Delete_Check : Test(1){
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'DeleteCheck passed');
	
}

sub errors : Test(){
	#TODO config -- load damaged version

	my $self = shift;
	my $volume = $self->{volume};
	my $ia_id = $volume->get_ia_id();
	my $download_dir = $volume->get_download_directory();
	my $scandata = "$download_dir/${ia_id}_scandata.xml";

	# missing $Scandata
	ok(! exists $scandata, 'caught missing scandata');

	# $leafNum undef
	# $leafNum = ""

	# $pageType eq 'Delete' w/ file present
	# $addToAccessFormats = 'false' w/ file present

	# $pageType eq 'Delete' w/ file missing
	# $addToAccessFormats = 'false' w/ file missing

	# test one file missing w/ no reference in scandata_xml
}

1;

__END__
