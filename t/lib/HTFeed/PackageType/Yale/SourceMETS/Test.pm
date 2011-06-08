package HTFeed::PackageType::Yale::SourceMETS::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use File::Path qw(make_path);
use Test::More;

sub SourceMETS : Test(1){

    test_config('undamaged');

	my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'Yale: SourceMETS succeeded with undamaged package');    
}

1;

__END__
