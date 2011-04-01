package HTFeed::PackageType::IA::VerifyManifest::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;
use File::Find;

sub check_files : Test(setup){
	#setup config
}

sub VerifyManifest : Test(1){
    my $self = shift;
	my $volume = $self->{volume};
	my $stage = $self->{test_stage};
	ok($stage->run(), 'Verification Successful');
}

sub Error : Test(1){
	#point to damaged version

    my $self = shift;
	my $volume = $self->{volume};
	my $objdir = $volume->get_download_directory();
	my $stage = $self->{test_stage};
	ok(! $objdir, 'Missing dir detected');
}

sub md5sum : Test{

	#TODO test md5sum check (see line 55)

	# test $core_mismatch

	# test where file_md5sum ne $manifest_md5sum
	my $file_md5sum = #get $file_md5sum
	my $manifest_md5sum = #get manifest_md5sum
	ok($file_md5sum ne $manifest_md5sum, 'md5sum error detected');

	#TODO test $mismatch_nonfatal
}

1;

__END__
