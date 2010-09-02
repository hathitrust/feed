package HTFeed::SuccessOrFailure;

use warnings;
use strict;

# return somthing true on failure, somthing false on success
sub failed{
	my $self = shift;
	unless ($self->succeeded()){
		return 1;
	}
	return;
}

# return somthing true on failure, somthing false on success
sub succeeded{
	my $self = shift;
	unless ($self->failed()){
		return 1;
	}
	return;
}

1;

__END__;
