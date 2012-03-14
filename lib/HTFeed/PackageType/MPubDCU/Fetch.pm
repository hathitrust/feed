package HTFeed::PackageType::MPubDCU::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage::Fetch);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use File::Find;

sub run {
	my $self = shift;

    $self->SUPER::run();

	my $volume = $self->{volume};
	my $objid = $volume->get_objid();
	my $packagetype = $volume->get_packagetype();

	my $fetch_base = get_config('staging'=>'fetch');

	my $source;
	my @paths;

	my $base="$fetch_base/mpub_dcu";

	# traverse dirs & symlinks
	# to find the fetch path
	my %options = (
		wanted 	=> 	sub {$source = "$File::Find::name"
					if (defined($File::Find::name) && ($File::Find::name =~ /forHT\/$objid$/));},
		follow => 1,
		follow_skip => 1,
	);

	find(\%options, $base);

	unless($source){
		$self->set_error('OperationFailed', operation => 'get fetch dir', detail => 'Path not found' );
		return;
	}

	my $dest = get_config('staging' => 'ingest');

	$self->fetch_from_source($source,$dest);
	$self->fix_line_endings($dest);

	$self->_set_done();
	return $self->succeeded();
}

1;
