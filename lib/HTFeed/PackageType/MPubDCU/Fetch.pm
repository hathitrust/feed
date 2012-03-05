package HTFeed::PackageType::MPubDCU::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage::Fetch);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use File::Find;

sub run {
	my $self = shift;

	my $volume = $self->{volume};
	my $packagetype = $volume->get_packagetype();
	my $objid = $volume->get_objid();

	my $fetch_base = get_config('staging'=>'fetch');

	my $source;


	my @paths;
	my $base="$fetch_base/mpub_dcu";
	
	find sub{
		push @paths, "$File::Find::name" if (-d $File::Find::name);
	},$base;
	
	foreach my $path(@paths){
		if($path =~ /forHT\/$objid$/){
			$source = $path;
		}
	}

	my $dest = get_config('staging' => 'ingest');

	$self->fetch_from_source($source,$dest);
	$self->fix_line_endings($dest);

	$self->_set_done();
	return $self->succeeded();
}

1;
