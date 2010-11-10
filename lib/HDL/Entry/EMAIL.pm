package HDL::Entry::EMAIL;

use warnings;
use strict;
use base qw(HDL::Entry);

sub new {
	my $class = shift;
	my $email = shift;
	return $class->SUPER::new(type => 'EMAIL', data => $email);
}

1;

__END__
