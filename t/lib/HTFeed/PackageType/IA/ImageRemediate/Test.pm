package HTFeed::PackageType::IA::ImageRemediate::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub get_scanData : Test(setup) {
	#setup config
}

sub ImageRemediate : Test(3){
	my $self  = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'ImageRemediate succeeeded');
}

sub TestErrors : Test{
	# TODO load damaged version
	my $self = shift.
	#my $file = [];
	
	# missing preingest_path
	ok(! $preingest_path, 'broken path detected');

	# $file doesn't match regexp /(\d{4})\.jp2$/
	unlike($file, =~ /(\d{4})\.jp2$/, '$file invalid');
	
	# $capture_time error
	my $capture_time = $self->get_capture_time($file);
	ok(! $capture_time, '');

	# $resolution errr
	ok(! $resolution, '');

	# undefined $gmtTimeStamp
	ok($gmtTimeStamp, undef, 'undefined gmtTimeStamp detected');

	# unmatched Timestamp regexp
	unlike($gmtTimeStamp, =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/, '$gmtTimeStamp mismatched');
}

1;

__END__
