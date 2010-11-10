package HDL::Entry::URL;

use warnings;
use strict;
use base qw(HDL::Entry);

sub new {
	my $class = shift;
	my $url = shift;
	return $class->SUPER::new(type => 'URL', data => $url);
}

1;

__END__
