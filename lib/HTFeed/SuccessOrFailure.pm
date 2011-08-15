package HTFeed::SuccessOrFailure;

use warnings;
use strict;
use Carp;

# return somthing true on failure, somthing false on success
# abstract
sub failed{
	croak 'subclass must impliment failed()';
}

# return false on failure, 1 on success
sub succeeded{
	my $self = shift;
	unless ($self->failed()){
		return 1;
	}
	return;
}

1;

__END__;
