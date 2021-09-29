package HTFeed::PackageType::Simple::Download;

use warnings;
use strict;
use base qw(HTFeed::Stage::Download);
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);

my $download_base = "dropbox:";

sub run {
  my $self = shift;

  my $volume = $self->{volume};
  # check if the item already exists at $volume->get_sip_location()
  my $sip_loc = $volume->get_sip_location();
  if (-f $sip_loc) {
    get_logger->trace("$sip_loc already exists");
  } else {
    my $rclone_config_path = get_config('rclone_config_path');
    unless (defined $rclone_config_path) {
      $self->set_error('StageFailed', detail => "rclone_config_path not configured");
      return 0;
    }
    my $nspkg = $volume->get_nspkg();
    my $dropbox_folder;
    eval { 
      $dropbox_folder = $nspkg->get('dropbox_folder');
    };
    if ($@) {
      $self->set_error('StageFailed', detail => $@);
      return $self->succeeded();
    }
    my $filename = $volume->get_SIP_filename();
    my $url = "$download_base$dropbox_folder/$filename";
    my $sip_directory = sprintf "%s/%s", $volume->get_sip_directory(), $volume->get_namespace();
    if (not -d $sip_directory) {
      get_logger->trace("Creating download directory $sip_directory");
      mkdir($sip_directory, 0770) or $self->set_error('OperationFailed', operation=>'mkdir', detail=>"$sip_directory could not be created");
    }
    my $cmd = $self->rclone_command($rclone_config_path, $url, $sip_directory);
    get_logger->trace("Running $cmd");
    my $output = `$cmd `;
    if (${^CHILD_ERROR_NATIVE} != 0) {
      $self->set_error('StageFailed', detail => $output);
      return 0;
    }
    my $outcome = PREMIS::Outcome->new('pass');
    $volume->record_premis_event("package_inspection", outcome => $outcome);
  }
  $self->_set_done();
  return $self->succeeded();
}

sub rclone {
  my $self = shift;

  return $self->{rclone} || 'rclone';
}

sub rclone_command {
  my $self   = shift;
  my $config = shift;
  my $src    = shift;
  my $dest   = shift;

  my @cmd = ($self->rclone, 'copy', '--config', $config, $src, $dest, '2>&1');
  return join(' ', @cmd);
}

1;

__END__
