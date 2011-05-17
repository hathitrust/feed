package HTFeed::PackageType::Yale::ImageRemediate::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use File::Path qw(make_path);
use Test::More;

sub prep : Test(setup){
	my $config = test_config('undamaged');
}

sub ImageRemediate : Test(1){
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'Yale: ImageRemediate succeeded with unbroken package');    
}

1;

__END__
