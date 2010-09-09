package HTFeed::Volume;

use warnings;
use strict;
use Log::Log4perl qw(get_logger);

our $logger = get_logger(__PACKAGE__);

sub new{
	my $package = shift;

	my $self = {
		volume_id		=> undef,
		namespace		=> undef,
		package_type	=> undef,
		@_,
		packagetype		=> undef,
		files			=> [],
		dir				=> undef,
		mets_name		=> undef,
		mets_xml		=> undef,
	}
	
	# fill out remaining fields, using 
	
	# check self for correctness
	
	
	bless ($self, $class);
	return $self;
}


sub validate_id{
	
}


1;

__END__;
