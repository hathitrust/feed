package HTFeed::PackageType::IA::VerifyManifest::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
#use HTFeed::Config qw(set_config);
use HTFeed::PackageType::IA::VerifyManifest;
use File::Copy;
use File::Find;
use File::Path qw(make_path);
use Test::More;

# Run IA VerifyManifest stage with normal conditions
sub ManifestVerification : Test(2){

	test_config('undamaged');
	my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'IA: Verify Manifest stage succeeded for undamaged package');
	ok($stage->stage_info(), 'IA: Verify Manifest stage info set for undamaged package');
}

# Run IA VeryfyManifest stage with missing manifest file
sub Missing : Test(2){
	test_config('damaged');
	my $self = shift;
    my $volume = $self->{volume};
    my $stage = $self->{test_stage};
	my $ia_id = $volume->get_ia_id();
	my $objdir   = $volume->get_download_directory();
	my $manifest = "$objdir/${ia_id}_files.xml";
	my $undamaged = "/htapps/feed.babel/test_data/staging/UNDAMAGED";

	# delete $manifest
	unlink("$manifest");

	# is $manifest missing?
	ok(! -e "$objdir/$manifest", "IA: missing manifest file detected: ${ia_id}_files.xml");

	#run stage to make sure we caught the missing file
	ok($stage->run(), 'IA: Verify Manifest stage passed with warnings on damaged package');

	# replace $manifest for next test
	my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_files.xml";
	copy($clean_copy,$objdir) or die "copy failed: $!";
}

sub pkgtype { 'ia' }
1;

__END__
