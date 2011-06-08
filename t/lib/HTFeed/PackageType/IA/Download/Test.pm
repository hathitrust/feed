package HTFeed::PackageType::IA::Download::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use File::Path qw(make_path);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use Test::More;

# test IA download stage with expected conditions

sub download_dir : Test(1){

	test_config('undamaged');

    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'IA: Download stage succeeded for undamaged package');
}

1;

__END__
