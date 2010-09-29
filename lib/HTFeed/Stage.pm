package HTFeed::Stage;

# abstract class, children must impliment following methods:
# run
# failed

use warnings;
use strict;
use Carp;
use Log::Log4perl qw(get_logger);

use base qw(HTFeed::SuccessOrFailure);

sub new{
	my $class = shift;

	# make sure we are instantiating a child class, not self
	if ($class eq __PACKAGE__){
		croak __PACKAGE__ . ' can only construct subclass objects';
	}
		
	my $self = {
		volume  => undef,
		@_,
		has_run => 0,
		failed  => 0,
	};
	
	unless ($self->{volume} && $self->{volume}->isa("HTFeed::Volume")){
		croak "$class cannot be constructed without an HTFeed::Volume";
	}

	bless ($self, $class);
	return $self;
}

# do somthing
# abstract
sub run{
	croak 'this is an abstract method';
}

sub _set_done{
	my $self = shift;
	$self->{has_run}++;
	return $self->{has_run};
}

sub failed{
	my $self = shift;
	return $self->{failed} if $self->{has_run};
	croak "can't check success until run()";
}

# set fail, log errors
sub _set_error{
	my $self = shift;
	my $error = shift;
	$self->{failed}++;

	# log error w/ l4p
	my $logger = get_logger(ref($self));
	$logger->error($error,volume => $self->{volume}->get_objid(),@_);
	return 1;
}

1;

__END__;
