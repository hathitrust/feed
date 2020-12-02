package HTFeed::PackageType::EMMA::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use File::Copy qw(move);
use HTFeed::Config;

sub move_sip {
  my $self = shift;
  my $target = shift;

  my $xml = $self->real_sip_location;
  $xml =~ s/\.zip$/.xml/;

  # move the zip & ensure the target directory is there
  $self->SUPER::move_sip($target);

  $target =~ s/.zip$/.xml/;

  move($xml,$target) or $self->set_error("OperationFailed",operation => "move",file => $xml,detail=>$!);

}


1;

