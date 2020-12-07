package HTFeed::Storage::ObjectStore;

use Log::Log4perl qw(get_logger);
use HTFeed::Storage;
use File::Pairtree qw(id2ppath s2ppchars);
use POSIX qw(strftime);
use HTFeed::Storage::S3;

use base qw(HTFeed::Storage);
use strict;

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(
      @_,
  );

	$self->{s3} ||= HTFeed::Storage::S3->new(
    bucket => $self->{config}{bucket},
    awscli => $self->{config}{awscli}
  );

  return $self;
}

sub object_path {
  my $self = shift;

  $self->{timestamp} ||= strftime("%Y%m%d%H%M%S",gmtime);

  return join(".",
    $self->{namespace},
    s2ppchars($self->{objid}),
    $self->{timestamp});
}

sub stage_path {
  die("Not implemented for ObjectStore");
}

sub stage {
  return 1;
}

sub prevalidate {
  return 1;
}

sub make_object_path {
  return 1;
}

sub move {
  my $self = shift;
  my $volume = $self->{volume};
  # TODO include --content-md5 and --metadata md5-checksum
  my $key_prefix = $self->object_path();

  my $mets_source = $volume->get_mets_path();
  get_logger()->trace("copying METS from: $mets_source");
  $self->put_object("$key_prefix.mets.xml",$mets_source);

  my $zip_source = $self->zip_source();
  my $zip_suffix = ".zip" . $self->{zip_suffix};
  $self->put_object("$key_prefix$zip_suffix",$zip_source);
}

sub put_object {
  my $self = shift;
  my $key = shift;
  my $source = shift;

  my $md5_base64 = $self->md5_base64($source);

  $self->{s3}->s3api("put-object",
    "--key","'$key'",
    "--body","'$source'",
    "--content-md5",$md5_base64,
    "--metadata","content-md5=" . $md5_base64);
}

sub md5_base64 {
  my $self = shift;
  my $file= shift;

  open( my $fh, "<", $file ) or croak("Can't open $file: $!");
  # From perldoc Digest::MD5:
  #
  # The base64 encoded string returned is not padded to be a multiple of 4
  # bytes long. If you want interoperability with other base64 encoded md5
  # digests you might want to append the string "==" to the result.

  return Digest::MD5->new->addfile($fh)->b64digest . '==';
}


1;
