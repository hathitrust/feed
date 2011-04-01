package HTFeed::PackageType::Yale::ImageRemediate::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::Yale::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub prep : Test(setup){
	#set method here
}

sub ImageRemediate : Test(1){
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'ImageRemediate succeeded');    
}

sub Failure : Test(1){
	#get damaged package
	#test error conditions
}

1;

__END__
