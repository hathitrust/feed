package HTFeed::PackageType::IA::DeleteCheck::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::IA::AbstractTest);
use HTFeed::Config qw(set_config);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

my $damaged = "/htapps/test.babel/feed/t/staging/DAMAGED";
my $undamaged = "/htapps/test.babel/feed/t/staging/UNDAMAGED";

sub Delete_Check : Test(2){
	set_config("$undamaged/download","staging"=>"download");
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'DeleteCheck passed');
	ok($stage->stage_info(), 'stage info updated');	
}

sub Missing : Test(2){

	# load damaged version
	set_config("$damaged","staging"=>"download");

	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $ia_id = $volume->get_ia_id();
	my $objdir = $volume->get_download_directory();
	my $scandata = "$objdir/${ia_id}_scandata.xml";

	unlink($scandata);

	# test version missing $Scandata
	subtest 'Caught missing scandata' => sub {
		ok(! -e $scandata, 'check that $scandata is missing...');
		ok(! $stage->run(), '...and we fail the stage');
	};
	
	my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_scandata.xml";
	copy($clean_copy,$objdir) or die "copy failed: $!";

}

sub Warnings : Test(1){
	set_config("$damaged","staging"=>"download");
	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $ia_id = $volume->get_ia_id();
	my $objdir = $volume->get_download_directory();
	
	#get bad version from "samples"
	my $samples = "$damaged/samples/ia/${ia_id}";
	my $broken_scanData = "$samples/${ia_id}_scandata.xml";
	copy($broken_scanData,$objdir) or die "copy failed: $!";

	#run the whole thing and see coverage
	ok($stage->run(), 'pass with warnings');

	#replace with standard scandata for next stage test
	my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_scandata.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";
}

1;

__END__
