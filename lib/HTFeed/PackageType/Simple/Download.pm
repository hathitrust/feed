package HTFeed::PackageType::Simple::Download;

use warnings;
use strict;
use base qw(HTFeed::Stage::Download);
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use HTFeed::Rclone;

sub run {
  my $self = shift;

  my $volume = $self->{volume};
  # check if the item already exists at $volume->get_sip_location()
  my $sip_loc = $volume->get_sip_location();
  if (-f $sip_loc) {
    get_logger->trace("$sip_loc already exists");
  } else {
    $self->download($volume);
  }
  $self->_set_done();
  return $self->succeeded();
}

sub download {
  my $self   = shift;
  my $volume = shift;

  my $url;
  eval {
    $url = $volume->dropbox_url;
  };
  if ($@) {
    $self->set_error('MissingFile', file => $volume->get_sip_location(), detail => $@);
    return;
  }
  my $sip_directory = sprintf "%s/%s", $volume->get_sip_directory(), $volume->get_namespace();
  if (not -d $sip_directory) {
    get_logger->trace("Creating download directory $sip_directory");
    mkdir($sip_directory, 0770) or $self->set_error('OperationFailed', operation=>'mkdir',
                                                    detail=>"$sip_directory could not be created");
  }
  eval {
    my $rclone = HTFeed::Rclone->new;
    $rclone->run('copy', $url, $sip_directory);
  };
  if ($@) {
    $self->set_error('OperationFailed', detail => $@);
  }
}

1;

__END__
