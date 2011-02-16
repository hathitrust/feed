#!/usr/bin/perl

package HTFeed::PackageType::MPub::Fetch;

use strict;
use warnings;
use base qw(HTFeed::PackageType);
use HTFeed::PackageType;
use HTFeed::Config qw(get_config);
use Log::Log4Perl qw(get_logger);
my $logger = get_logger(__PACKAGE__();

sub run {
	my $self = shift;
	my $volume = $self->{volume};
	my $objid = $volume->get_objid();
	my $filename = $volume->get_SIP>filename(); #special filename for ump?

	#XXX get type; get volume from 'forHT' (ie /mpub_dcu/<type>/forHT)
	my $source = ;
	my $staging_dir = $volume->get_download_directory();

	if(! -e $staging_dir) {
		mkdir $staging_dir or die("Can't mkdir $staging_dir: $!");
	}

	#alter method to fetch from dir, rather than download from URL?
	$self->download(url => $source, path => $staging_dir, filename => $filename,);

	$self->_set_done();
	return $self->succeeded();
}

1;

__END__;
