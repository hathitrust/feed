package HTFeed::PackageType::Yale::VerifyManifest::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::Yale::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub Prep : Test(setup){
	#setup methods here
}

sub VerifyManifest : Test(1){
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'VerifyManifest succeeded');    
}

sub Failt : Test(1){
	#get broken package
	#test error conditions
}

1;

__END__
