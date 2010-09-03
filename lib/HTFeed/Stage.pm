package HTFeed::Stage;

use warnings;
use strict;
use Carp;

use base qw(HTFeed::SuccessOrFailure);

sub new{
    my $class = shift;

    # make sure we are instantiating a child class, not self
	if ($class eq __PACKAGE__){
	    croak __PACKAGE__ . " can only construct subclass objects";
	}
	    
    my $self = {
        volume  => undef,
        @_,
        has_run => 0,
        failed  => 0,
    };
    
    unless ($self->{volume} && ref($self->{volume}) eq "HTFeed::Volume"){
		croak "$class cannot be constructed without an HTFeed::Volume";
	}

    bless ($self, $class);
    return $self;
}

# do somthing
# abstract
sub run{
    croak "this is an abstract method";
}

1;

__END__;
