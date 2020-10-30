package AWS;

use warnings;
use strict;
use JSON::XS;

use base qw( Exporter );
our @EXPORT_OK = qw( list_objects get_object );

sub list_objects {
  my ($bucket, $last_id) = @_;

  my $cmd = "aws s3api list-objects-v2 --bucket $bucket";
  $cmd .= " --start-after $last_id" if defined $last_id;
  my $buffer = `$cmd`;
  die "ERROR calling $cmd: $?" if $?;
  return unless defined $buffer and length $buffer;
  my $jsonxs = JSON::XS->new->utf8;
  my $data = $jsonxs->decode($buffer);
  return $data;
}

sub get_object {
  my ($bucket, $key, $dest) = @_;

  my $cmd = "aws s3api get-object --bucket $bucket --key $key $dest";
  my $buffer = `$cmd`;
  die "ERROR calling $cmd: $?" if $?;
  return $buffer;
}
