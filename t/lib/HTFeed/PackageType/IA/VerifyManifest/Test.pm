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

my $damaged = "/htapps/test.babel/feed/t/staging/DAMAGED";
my $undamaged = "/htapps/test.babel/feed/t/staging/UNDAMAGED";

sub ManifestVerification : Test(2){
	set_config("$undamaged/download","staging"=>"download");
	my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'Verification Successful');
	ok($stage->stage_info(), 'stage info ok');
}

sub Missing : Test(2){
	set_config("$damaged","staging"=>"download");
	my $self = shift;
    my $volume = $self->{volume};
    my $stage = $self->{test_stage};
	my $ia_id = $volume->get_ia_id();
	my $objdir   = $volume->get_download_directory();
	my $manifest = "$objdir/${ia_id}_files.xml";

	unlink("$manifest");

	#detect missing files.xml
	ok(! -e "$objdir/$manifest", "missing file detected");

	#run again for failure coverage
	ok($stage->run(), 'passed with warnings');

	my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_files.xml";
	copy($clean_copy,$objdir) or die "copy failed: $!";
}

1;

__END__
