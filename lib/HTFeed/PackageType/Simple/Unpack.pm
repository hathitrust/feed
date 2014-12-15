package HTFeed::PackageType::Simple::Unpack;

use strict;
use warnings;
use base qw(HTFeed::Stage::Unpack);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use File::Find;

sub run {
  my $self = shift;
  $self->SUPER::run();


  my $volume = $self->{volume};
  my $packagetype = $volume->get_packagetype();
  my $pt_objid = $volume->get_pt_objid();

  my $download_dir = get_config('staging'=>'download');

  my $dest = $volume->get_preingest_directory();

  my $file = $volume->get_sip_location();

  # for retrying
  if(not -e $file) {
    $file = $volume->get_failure_sip_location();
  }

  if(-e $file) {
    $self->unzip_file($file,$dest);
    $self->_set_done();
  } else {
    $self->set_error("MissingFile",file=>$volume->get_sip_location);
  }

  return $self->succeeded();
}

1;

