package HTFeed::PackageType::Yale::SourceMETS::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::Yale::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub get_methods : Test(setup){
	#setup methods here
}

sub SourceMETS : Test(1){
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'SourceMETS succeeded');    
}

sub Fail : Test(1){
	#get damaged package
	#test error conditions
}

1;

__END__
