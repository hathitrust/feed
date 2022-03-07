package HTFeed::ClamScan;

use strict;
use HTFeed::Config qw(get_config);

# Emulate ClamAV::Daemon interface, but run clamscan locally.

sub new {
  my $class = shift;

  my $self = bless({},$class);
  $self->{clamscan} = get_config('clamscan');
  return $self;
}

sub ping {
}

sub scan_path {
  my $self = shift;
  my $path = shift;

  my $clamscan = $self->{clamscan};
  my $output = qx($clamscan "$path" 2>&1);
  my $exitcode = $?;
  my $result;

  # couldn't run
  if(defined $output and $exitcode == 0) {
    # success
    $result = undef;
  } elsif(not defined $output) {
    $result = "Couldn't run $clamscan; exit code $exitcode";
  } else {
    $result = "Virus found or error occurred (exit code $exitcode): $output";
  }

  return ($path, $result);
}

1;
