package HTFeed::PackageType::IA::Download::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub scandata : Test(setup) {
	#get config data for
	#'damaged' & 'undamaged'
}

sub download_dir : Test(2){
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'IA Download succeeded');
}

sub no_scandata : Test(1){
	#TODO test download w/ missing scandata
}

sub noncore_missing : Test(1){
	# TODO push $file to @noncore_missing
	is(@noncore_missing, $file, 'nonecore_missing detected');
}

1;

__END__
