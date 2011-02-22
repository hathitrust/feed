package HTFeed::PackageType::MPub::Fetch;

use strict;
use warnings;
use HTFeed::Config qw(get_config);

sub run {
	my $self = shift;
	my $volume = $self->{volume};

	my $objid = $volume->get_objid();
	my $type = $volume->get_nspkg();

	my $source = "/htprep/mpub_dcu/" . $type . "/forHT"; 
	my $staging_dir = $volume->get_download_directory();

	if(! -e $staging_dir) {
		mkdir $staging_dir or die("Can't mkdir $staging_dir: $!");
	}

	#TODO copy files to staging directory

	$self->_set_done();
	return $self->succeeded();
}

1;

__END__;
