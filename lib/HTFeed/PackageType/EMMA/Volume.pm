package HTFeed::PackageType::EMMA::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use File::Copy qw(move);
use HTFeed::Config;
use HTFeed::Storage::S3;

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

sub clean_sip_success {
  my $self = shift;

  $self->SUPER::clean_sip_success();
  my $s3 = HTFeed::Storage::S3->new(
    bucket => get_config('emma','bucket'),
    awscli => get_config('awscli')
  );
  my $zip = $self->get_zip_filename;
  my $xml = $zip;
  $xml =~ s/\.zip$/.xml/;
  $s3->rm('/' . $zip);
  $s3->rm('/' . $xml);
}

1;

