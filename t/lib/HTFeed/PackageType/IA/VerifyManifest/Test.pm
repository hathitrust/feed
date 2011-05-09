package HTFeed::PackageType::IA::VerifyManifest::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::IA::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use HTFeed::Config qw(set_config);
use File::Copy;
use File::Find;
use File::Path qw(make_path);
use Test::More;

#This will go away when config method is finalized in Test/Support.pm
my $damaged = "/htapps/test.babel/feed/t/staging/DAMAGED";
my $undamaged = "/htapps/test.babel/feed/t/staging/UNDAMAGED";

# Run IA VerifyManifest stage with normal conditions
sub ManifestVerification : Test(2){
	set_config("$undamaged/download","staging"=>"download");
	my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'IA: Verify Manifest stage succeeded for undamaged package');
	ok($stage->stage_info(), 'IA: Verify Manifest stage info set for undamaged package');
}

# Run IA VeryfyManifest stage with missing manifest file
sub Missing : Test(2){
	set_config("$damaged","staging"=>"download");
	my $self = shift;
    my $volume = $self->{volume};
    my $stage = $self->{test_stage};
	my $ia_id = $volume->get_ia_id();
	my $objdir   = $volume->get_download_directory();
	my $manifest = "$objdir/${ia_id}_files.xml";

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

1;

__END__
