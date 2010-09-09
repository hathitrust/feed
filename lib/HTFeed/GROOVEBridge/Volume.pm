package HTFeed::GROOVEBridge::Volume;

use warnings;
use strict;
use Log::Log4perl qw(get_logger);

use base qw(HTFeed::Volume);

our $logger = get_logger(__PACKAGE__);

sub new{
	my $class = shift;
	my $book = shift;

	my %fields = (
		
	);
	
	my $self = HTFeed::Volume->new(%fields);
	bless ($self, $class);
	
	$self->{book} = $book
	
	return $self;
}




1;

__END__;
