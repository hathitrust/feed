package HTFeed::PackageType::IA::DeleteCheck::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::IA::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub Delete_Check : Test(1){
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'DeleteCheck passed');
	
}

sub errors : Test(1){
	#TODO config -- load damaged version

	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $ia_id = $volume->get_ia_id();
	my $download_dir = $volume->get_download_directory();
	my $scandata = "$download_dir/${ia_id}_scandata.xml";

	# missing $Scandata
	ok(! -e $scandata, 'caught missing scandata');

	ok($stage->run(), 'damaged package test');
	# tests one instance of $leafNum undef
	# tests one instance of $leafNum = ""
	# tests one instance of $pageType eq 'Delete' w/ file present
	# tests one instance of $addToAccessFormats = 'false' w/ file present
	# tests one instance of $pageType eq 'Delete' w/ file missing
	# tests one instance of $addToAccessFormats = 'false' w/ file missing
	# tests one instance of  file missing w/ no reference in scandata_xml
}

1;

__END__
