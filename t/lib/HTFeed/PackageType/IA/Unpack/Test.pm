package HTFeed::PackageType::IA::Unpack::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::IA::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use HTFeed::Config qw(set_config);
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

	#TODO use config setup method once Support/Test.pm is finalized
	set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/preingest','staging'=>'preingest');
	set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/zipfile','staging'=>'zipfile');
	set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/ingest','staging'=>'ingest');
	set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/download','staging'=>'download');

    my $self = shift;
	my $volume = $self->{volume};
	my $stage = $self->{test_stage};
	ok($stage->run, 'IA: Unpack stage succeeds with undamaged volume');
}

1;

__END__
