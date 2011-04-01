package HTFeed::PackageType::IA::Unpack::Test;

use warnings;
use strict;

use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub fixDir : Test(setup) {
	#set config
}

sub Unpack : Test(1){
    my $self = shift;
	my $volume = $self->{volume};
	my $stage = $self->{test_stage};
	ok($stage->run, 'Unpacked');
}

sub Errors : Test{
	# TODO test ram_disk_size error
}

1;

__END__
