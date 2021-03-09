# Mock functions for tests involving clamav

package HTFeed::Test::MockClamAV;

sub new {
  my $class = shift;
  my $self = {};

  return bless( $self, $class);
}

sub ping {
}

sub scan_path {
  my $self = shift;
  my $path = shift;

  return ($path, undef);
}


1;
