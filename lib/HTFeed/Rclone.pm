package HTFeed::Rclone;

use warnings;
use strict;
use HTFeed::Config;
use Log::Log4perl qw(get_logger);
use Carp qw(croak);

sub new {
  my $class = shift;
  my $self = { @_ };
  bless($self,$class);
  return $self;
}

sub run {
  my $self       = shift;
  my $subcommand = shift;

  my $rclone_config_path = get_config('rclone_config_path');
  if (not defined $rclone_config_path) {
    croak('rclone_config_path not configured');
  }
  my $cmd = join(' ', ($self->_rclone, $subcommand, '--config', $rclone_config_path, @_, '2>&1'));
  get_logger->trace("Running $cmd");
  my $output = `$cmd `;
  if (${^CHILD_ERROR_NATIVE} != 0) {
    croak($output);
  }
}

sub _rclone {
  my $self = shift;

  return $ENV{rclone} || 'rclone';
}

1;

__END__
