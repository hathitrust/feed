package HTFeed::Stage::Fake;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use Test::More;

sub run{
    my $self = shift;
    $self->_set_done();
    return $self->succeeded();
}

# this will only run if a test blows up
sub set_error{
    my $self = shift;
    my $message = join q(, ), @_;
    # we shouldn't get to this line
    fail($message);
    return;
}

sub authorize_user_agent {

  my $self = shift;
  my $ua = shift;

  return $ua;
}
1;

__END__
