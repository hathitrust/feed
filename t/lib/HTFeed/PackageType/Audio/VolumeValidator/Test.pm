package HTFeed::PackageType::Audio::VolumeValidator::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::Audio::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub Delete_Check : Test(1){
    my $self = shift;
    my $stage = $self->{test_stage};
    ok($stage->run(), 'DeleteCheck passed');

}

1;

__END__
