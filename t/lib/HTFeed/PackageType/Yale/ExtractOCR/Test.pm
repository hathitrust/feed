package HTFeed::PackageType::Yale::ExtractOCR::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use File::Path qw(make_path);
use Test::More;

sub ExtractOCR : Test(2){

	test_config('undamaged');

    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'Yale: ExtractOCR succeeded with undamaged pacakge');
	ok($stage->stage_info(), 'Yale: ExtractOCR stage info returned for unbroken package');
}

1;

__END__
