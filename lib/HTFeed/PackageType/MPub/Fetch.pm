package HTFeed::PackageType::MPub::Fetch;

use strict;
use warnings;

use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

sub run {
	my $self = shift;
	my $volume = $self->{volume};
	my $objid = $volume->get_objid();
	my $type = shift; #XXX get correct flavor type

	my $source = "/htprep/mpub_dcu/" . $type . "/forHT"; 
	my $staging_dir = $volume->get_download_directory();

	if(! -e $staging_dir) {
		mkdir $staging_dir or die("Can't mkdir $staging_dir: $!");
	}

	#alter method to fetch from dir, rather than download from URL?
	$self->download(url => $source, path => $staging_dir, filename => $volume->get_SIP_filename());

	$self->_set_done();
	return $self->succeeded();
}

1;

__END__;
