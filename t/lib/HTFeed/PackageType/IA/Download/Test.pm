package HTFeed::PackageType::IA::Download::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::IA::AbstractTest);
use File::Path qw(make_path);
use HTFeed::Test::Support qw(get_fake_stage);
use Test::More;

sub download_dir : Test(1){
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'IA Download succeeded');
}

1;

__END__
