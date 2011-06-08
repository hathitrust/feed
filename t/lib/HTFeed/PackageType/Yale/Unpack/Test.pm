package HTFeed::PackageType::Yale::Unpack::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

sub config : Test(setup){

	test_config('undamaged');

    # cleanup staging area prior to unpacking
    my $self = shift;
    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $dir = "/htapps/test.babel/feed/t/staging/UNDAMAGED";
    my @locs = ("preingest","ingest","zipfile");
    for my $loc(@locs){
        my $gone = "$dir/$loc/$objid";
        if(-e $gone){
            `rm -r $gone`;
        }
    }
}

sub Unpack : Test(1){
    my $self = shift;
    my $stage = $self->{test_stage};
	ok($stage->run(), 'Yale: Unpack succeeded with undamaged package');
}

1;

__END__
