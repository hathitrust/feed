package HTFeed::PackageType::IA::Unpack::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
#use HTFeed::Config qw(set_config);
use File::Path qw(make_path);
use Test::More;

sub temp_setup : Test(setup){

	# verify that staging dirs are clean
	my $self = shift;
	my $volume = $self->{volume};
	my $objid = $volume->get_objid();
	$objid =~ s/:\//+\//g;
	$objid =~ s/\//=/g;
	my $dir = "/htapps/test.babel/feed/t/staging/UNDAMAGED";
	my @locs = ("preingest","ingest","zipfile");
	for my $loc(@locs){
		my $gone = "$dir/$loc/$objid";
		if(-e $gone){
			`rm -r $gone`;
		}
	}
}

# Run IA Unpack stage on undamaged package
sub Unpack : Test(1){

	test_config('undamaged');

    my $self = shift;
	my $volume = $self->{volume};
	my $stage = $self->{test_stage};
	ok($stage->run, 'IA: Unpack stage succeeds with undamaged volume');
}

1;

__END__
